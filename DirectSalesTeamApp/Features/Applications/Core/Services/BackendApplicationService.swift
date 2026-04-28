import Foundation
import Combine
import GRPCNIOTransportHTTP2
import GRPCCore
import SwiftProtobuf
import GRPCProtobuf

final class BackendApplicationService: ApplicationServiceProtocol {
    private let tokenStore: TokenStore
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let authClient: AuthGRPCClient

    init(
        tokenStore: TokenStore = .shared,
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.tokenStore = tokenStore
        self.grpcClient = grpcClient
        self.authClient = AuthGRPCClient(grpcClient: grpcClient, tokenStore: tokenStore)
    }

    func fetchApplications() -> AnyPublisher<[LoanApplication], Error> {
        Future { promise in
            Task {
                do {
                    var req = Loan_ListLoanApplicationsRequest()
                    req.limit = 200; req.offset = 0; req.branchID = ""
                    let resp: Loan_ListLoanApplicationsResponse =
                        try await self.unaryLoanCall(method: "ListLoanApplications", request: req)
                    let meta = LeadMetadataStore()
                    let filtered = resp.items.filter {
                        $0.status != .draft && $0.status != .unspecified && $0.status != .cancelled
                    }

                    let apps: [LoanApplication] = try await withThrowingTaskGroup(of: LoanApplication.self) { group in
                        for proto in filtered {
                            group.addTask {
                                var application = self.map(proto)
                                if let m = meta.metadata(for: proto.id) {
                                    application.name = m.name
                                    application.phone = m.phone
                                } else if !proto.primaryBorrowerProfileID.isEmpty {
                                    if let profile = try? await self.authClient.getBorrowerProfile(userID: proto.primaryBorrowerProfileID) {
                                        let fullName = [profile.firstName, profile.lastName]
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " ")
                                        let resolvedName = fullName.isEmpty
                                            ? (proto.referenceNumber.isEmpty ? "Application" : proto.referenceNumber)
                                            : fullName
                                        application.name = resolvedName
                                        meta.save(
                                            applicationID: proto.id,
                                            name: resolvedName,
                                            phone: "",
                                            email: "",
                                            loanProductID: nil
                                        )
                                    } else {
                                        application.name = proto.referenceNumber.isEmpty ? "Application" : proto.referenceNumber
                                    }
                                }
                                return application
                            }
                        }
                        var results: [LoanApplication] = []
                        for try await application in group {
                            results.append(application)
                        }
                        return results.sorted { $0.createdAt > $1.createdAt }
                    }
                    promise(.success(apps))
                } catch { promise(.failure(error)) }
            }
        }.eraseToAnyPublisher()
    }

    func updateStatus(id: String, status: ApplicationStatus) -> AnyPublisher<LoanApplication, Error> {
        // TODO: wire to UpdateLoanApplicationStatus when backend supports it from DST role
        Fail(error: URLError(.unsupportedURL)).eraseToAnyPublisher()
    }

    private func map(_ app: Loan_LoanApplication) -> LoanApplication {
        LoanApplication(
            id: app.id,
            leadId: nil,
            name: app.referenceNumber.isEmpty ? "Application" : app.referenceNumber,
            phone: "",
            referenceNumber: app.referenceNumber.isEmpty ? nil : app.referenceNumber,
            loanType: mapLoanType(app.loanProductName),
            loanAmount: Double(app.requestedAmount) ?? 0,
            status: mapStatus(app.status),
            createdAt: ISO8601DateFormatter().date(from: app.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: app.updatedAt) ?? Date(),
            slaDays: nil,
            statusLabel: mapStatusLabel(app.status),
            bankName: app.branchName,
            sanctionedAmount: nil, disbursedAmount: nil, rmName: nil
        )
    }

    private func mapStatus(_ s: Loan_LoanApplicationStatus) -> ApplicationStatus {
        switch s {
        case .submitted:                                 return .submitted
        case .underReview, .officerReview:              return .officerReview
        case .officerApproved:                          return .officerApproved
        case .managerReview:                            return .managerReview
        case .managerApproved:                          return .managerApproved
        case .approved:                                 return .approved
        case .rejected, .officerRejected, .managerRejected:
            return .rejected
        case .disbursed:                                return .disbursed
        default:                                        return .submitted
        }
    }
    private func mapStatusLabel(_ s: Loan_LoanApplicationStatus) -> String {
        switch s {
        case .submitted:                                 return "Submitted for review"
        case .underReview, .officerReview:              return "Officer review in progress"
        case .officerApproved:                          return "Awaiting manager review"
        case .managerReview:                            return "Manager review in progress"
        case .managerApproved:                          return "Sanctioned"
        case .approved:                                 return "Approved"
        case .rejected, .officerRejected, .managerRejected:
            return "Closed"
        case .disbursed:                                return "Completed"
        default:                                        return "Processing"
        }
    }
    private func mapLoanType(_ productName: String) -> LoanType {
        let name = productName.lowercased()
        if name.contains("home") { return .home }
        if name.contains("auto") || name.contains("vehicle") || name.contains("car") { return .auto }
        if name.contains("education") { return .education }
        if name.contains("business") { return .business }
        return .personal
    }

    private func unaryLoanCall<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request
    ) async throws -> Response {
        do {
            return try await performUnaryLoanCall(method: method, request: request)
        } catch let rpcError as RPCError where rpcError.code == .cancelled {
            print("DEBUG: ApplicationService unaryLoanCall '\(method)' cancelled; retrying once...")
            try await Task.sleep(for: .milliseconds(200))
            return try await performUnaryLoanCall(method: method, request: request)
        }
    }

    private func performUnaryLoanCall<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request
    ) async throws -> Response {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw AuthError.unauthenticated
        }
        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let rpcRequest = ClientRequest<Request>(message: request, metadata: metadata)
        let response: ClientResponse<Response> = try await grpcClient.unary(
            request: rpcRequest,
            descriptor: MethodDescriptor(
                service: ServiceDescriptor(fullyQualifiedService: "loan.v1.LoanService"),
                method: method
            ),
            serializer: ProtobufSerializer<Request>(),
            deserializer: ProtobufDeserializer<Response>(),
            options: options,
            onResponse: { $0 }
        )
        return try response.message
    }
}
