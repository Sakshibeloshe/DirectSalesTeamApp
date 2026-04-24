import Foundation
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import SwiftProtobuf

struct BorrowerLookupResult: Sendable {
    let borrowerProfileID: String
    let displayName: String
}

struct BorrowerLookupService {
    private let tokenStore: TokenStore
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>

    init(
        tokenStore: TokenStore = .shared,
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.tokenStore = tokenStore
        self.grpcClient = grpcClient
    }

    func resolveBorrower(email: String, phone: String) async throws -> BorrowerLookupResult? {
        let phoneDigits = phone.filter(\.isNumber)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let queries = [normalizedEmail, phoneDigits].filter { !$0.isEmpty }
        guard !queries.isEmpty else { return nil }

        for query in queries {
            let items = try await searchBorrowerWithRetry(query: query)
            if let match = bestBorrowerMatch(
                from: items,
                normalizedEmail: normalizedEmail,
                phoneDigits: phoneDigits
            ) {
                let name = match.email.isEmpty ? match.phone : match.email
                return BorrowerLookupResult(borrowerProfileID: match.borrowerProfileID, displayName: name)
            }
        }

        return nil
    }

    private func bestBorrowerMatch(
        from items: [BorrowerSignupStatusSearchItem],
        normalizedEmail: String,
        phoneDigits: String
    ) -> BorrowerSignupStatusSearchItem? {
        let candidates = items.filter { !$0.borrowerProfileID.isEmpty }
        guard !candidates.isEmpty else { return nil }

        if !phoneDigits.isEmpty,
           let phoneExactMatch = candidates.first(where: { normalizedDigits($0.phone) == phoneDigits }) {
            return phoneExactMatch
        }

        if !normalizedEmail.isEmpty {
            let targetEmail = normalizedEmail.lowercased()
            if let emailExactMatch = candidates.first(where: { $0.email.lowercased() == targetEmail }) {
                return emailExactMatch
            }
        }

        return candidates.first
    }

    private func normalizedDigits(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private func searchBorrowerWithRetry(query: String) async throws -> [BorrowerSignupStatusSearchItem] {
        do {
            return try await searchBorrowerSignupStatus(query: query)
        } catch let rpcError as RPCError where rpcError.code == .cancelled {
            // Observed intermittent cancellations from transport; retry once.
            try await Task.sleep(for: .milliseconds(150))
            return try await searchBorrowerSignupStatus(query: query)
        }
    }

    private func searchBorrowerSignupStatus(query: String, limit: Int32 = 20, offset: Int32 = 0) async throws -> [BorrowerSignupStatusSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw AuthError.unauthenticated
        }

        var request = Auth_SearchBorrowerSignupStatusRequest()
        request.query = trimmed
        request.limit = limit
        request.offset = offset

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let rpcRequest = ClientRequest<Auth_SearchBorrowerSignupStatusRequest>(message: request, metadata: metadata)
        do {
            let response: ClientResponse<Auth_SearchBorrowerSignupStatusResponse> = try await grpcClient.unary(
                request: rpcRequest,
                descriptor: MethodDescriptor(
                    service: ServiceDescriptor(fullyQualifiedService: "auth.v1.AuthService"),
                    method: "SearchBorrowerSignupStatus"
                ),
                serializer: ProtobufSerializer<Auth_SearchBorrowerSignupStatusRequest>(),
                deserializer: ProtobufDeserializer<Auth_SearchBorrowerSignupStatusResponse>(),
                options: options,
                onResponse: { $0 }
            )
            return try response.message.items.map(BorrowerSignupStatusSearchItem.init(proto:))
        } catch let rpcError as RPCError {
            let lowered = rpcError.message.lowercased()
            if rpcError.code == .failedPrecondition &&
                (lowered.contains("password change required") || lowered.contains("requiring_password_change")) {
                throw BorrowerLookupError.passwordChangeRequired
            }
            throw BorrowerLookupError.rpc(code: rpcError.code.rawValue, message: rpcError.message)
        }
    }
}

enum BorrowerLookupError: LocalizedError {
    case passwordChangeRequired
    case rpc(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .passwordChangeRequired:
            return "Password change is required for this DST account before borrower verification can continue. Please update your password and try again."
        case .rpc(let code, let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Borrower lookup failed (RPC code: \(code))."
                : "Borrower lookup failed (RPC code: \(code)): \(trimmed)"
        }
    }
}

private struct BorrowerSignupStatusSearchItem: Identifiable, Hashable, Sendable {
    let userID: String
    let email: String
    let phone: String
    let isActive: Bool
    let borrowerProfileID: String
    var id: String { userID }
    fileprivate init(proto: Auth_BorrowerSignupStatusItem) {
        self.userID = proto.userID
        self.email = proto.email
        self.phone = proto.phone
        self.isActive = proto.isActive
        self.borrowerProfileID = proto.borrowerProfileID
    }
}

private struct Auth_SearchBorrowerSignupStatusRequest: Sendable {
    var query: String = ""
    var limit: Int32 = 0
    var offset: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

private struct Auth_BorrowerSignupStatusItem: Sendable {
    var userID: String = ""
    var email: String = ""
    var phone: String = ""
    var isActive: Bool = false
    var borrowerProfileID: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

private struct Auth_SearchBorrowerSignupStatusResponse: Sendable {
    var items: [Auth_BorrowerSignupStatusItem] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

extension Auth_SearchBorrowerSignupStatusRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &query)
            case 2: try decoder.decodeSingularInt32Field(value: &limit)
            case 3: try decoder.decodeSingularInt32Field(value: &offset)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !query.isEmpty { try visitor.visitSingularStringField(value: query, fieldNumber: 1) }
        if limit != 0 { try visitor.visitSingularInt32Field(value: limit, fieldNumber: 2) }
        if offset != 0 { try visitor.visitSingularInt32Field(value: offset, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Auth_BorrowerSignupStatusItem: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.BorrowerSignupStatusItem"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &userID)
            case 2: try decoder.decodeSingularStringField(value: &email)
            case 3: try decoder.decodeSingularStringField(value: &phone)
            case 6: try decoder.decodeSingularBoolField(value: &isActive)
            case 9: try decoder.decodeSingularStringField(value: &borrowerProfileID)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !userID.isEmpty { try visitor.visitSingularStringField(value: userID, fieldNumber: 1) }
        if !email.isEmpty { try visitor.visitSingularStringField(value: email, fieldNumber: 2) }
        if !phone.isEmpty { try visitor.visitSingularStringField(value: phone, fieldNumber: 3) }
        if isActive { try visitor.visitSingularBoolField(value: isActive, fieldNumber: 6) }
        if !borrowerProfileID.isEmpty { try visitor.visitSingularStringField(value: borrowerProfileID, fieldNumber: 9) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Auth_SearchBorrowerSignupStatusResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !items.isEmpty { try visitor.visitRepeatedMessageField(value: items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
}
