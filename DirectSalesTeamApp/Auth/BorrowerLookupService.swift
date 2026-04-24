import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

struct BorrowerLookupResult: Sendable {
    let borrowerProfileID: String?
    let displayName: String
}

struct BorrowerLookupService {
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>

    init(
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.grpcClient = grpcClient
    }

    func resolveBorrower(email: String, phone: String) async throws -> BorrowerLookupResult? {
        let phoneDigits = phone.filter(\.isNumber)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let queries = [normalizedEmail, phoneDigits].filter { !$0.isEmpty }
        guard !queries.isEmpty else { return nil }

        for query in queries {
            if let result = try await checkBorrowerExists(emailOrPhone: query) {
                return BorrowerLookupResult(
                    borrowerProfileID: nil,
                    displayName: result
                )
            }
        }

        return nil
    }

    private func checkBorrowerExists(emailOrPhone: String) async throws -> String? {
        let normalized = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let authClient = Auth_V1_AuthService.Client(wrapping: grpcClient)
        var request = Auth_V1_InitiateForgotPasswordRequest()
        request.emailOrPhone = normalized

        do {
            let response = try await authClient.initiateForgotPassword(
                request: .init(message: request, metadata: Metadata()),
                options: AuthCallOptionsFactory.unauthenticated()
            )

            if response.challengeSent {
                let target = response.maskedEmail.isEmpty ? response.maskedPhone : response.maskedEmail
                return target.isEmpty ? normalized : target
            }
            return nil
        } catch let rpc as RPCError {
            // Not found-style responses should be treated as "borrower not found".
            if rpc.code == .notFound || rpc.code == .failedPrecondition || rpc.code == .invalidArgument {
                return nil
            }

            let message = rpc.message.lowercased()
            if message.contains("not found") || message.contains("does not exist") || message.contains("no user") {
                return nil
            }
            throw rpc
        }
    }
}
