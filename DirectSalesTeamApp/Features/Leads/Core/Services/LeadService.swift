import Foundation
import Combine

// MARK: - Lead Service Protocol
// Swap MockLeadService with a real APILeadService without touching ViewModels
protocol LeadServiceProtocol {
    func fetchLeads() -> AnyPublisher<[Lead], Error>
    func addLead(_ lead: Lead) -> AnyPublisher<Lead, Error>
    func updateLead(_ lead: Lead) -> AnyPublisher<Lead, Error>
    func deleteLead(id: UUID) -> AnyPublisher<Void, Error>
}

// MARK: - Mock Service
final class MockLeadService: LeadServiceProtocol {

    static let shared = MockLeadService()

    private let mockLeads: [Lead] = [
        Lead(id: UUID(), name: "Arjun Mehta",   phone: "9876543210", email: "arjun@email.com",   loanType: .home,      loanAmount: 3_500_000, status: .new,         createdAt: Date().addingTimeInterval(-7200),  updatedAt: Date(), assignedRM: "Priya S", branchCode: "MYS01"),
        Lead(id: UUID(), name: "Priya Sharma",  phone: "9845001234", email: "priya@email.com",   loanType: .personal,  loanAmount:   800_000, status: .docsPending, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date(), assignedRM: nil,       branchCode: "MYS01"),
        Lead(id: UUID(), name: "Rohit Verma",   phone: "9900112233", email: "rohit@email.com",   loanType: .business,  loanAmount: 5_000_000, status: .submitted,   createdAt: Date().addingTimeInterval(-172800),updatedAt: Date(), assignedRM: "Priya S", branchCode: "MYS02"),
        Lead(id: UUID(), name: "Kavitha Nair",  phone: "9844556677", email: "kavitha@email.com", loanType: .home,      loanAmount: 6_000_000, status: .rejected,    createdAt: Date().addingTimeInterval(-259200),updatedAt: Date(), assignedRM: "Vikram R", branchCode: "MYS01"),
        Lead(id: UUID(), name: "Siddharth Rao", phone: "7760001234", email: "sid@email.com",     loanType: .auto,      loanAmount: 1_200_000, status: .new,         createdAt: Date().addingTimeInterval(-3600),  updatedAt: Date(), assignedRM: nil,        branchCode: "MYS03"),
        Lead(id: UUID(), name: "Meera Patel",   phone: "9741236547", email: "meera@email.com",   loanType: .personal,  loanAmount:   500_000, status: .docsPending, createdAt: Date().addingTimeInterval(-14400), updatedAt: Date(), assignedRM: "Priya S",  branchCode: "MYS01"),
        Lead(id: UUID(), name: "Kiran Hegde",   phone: "9632147852", email: "kiran@email.com",   loanType: .education, loanAmount: 1_500_000, status: .approved,    createdAt: Date().addingTimeInterval(-432000),updatedAt: Date(), assignedRM: "Vikram R", branchCode: "MYS02"),
        Lead(id: UUID(), name: "Deepa Nanda",   phone: "8867452130", email: "deepa@email.com",   loanType: .home,      loanAmount: 4_200_000, status: .disbursed,   createdAt: Date().addingTimeInterval(-604800),updatedAt: Date(), assignedRM: "Priya S",  branchCode: "MYS01"),
    ]

    func fetchLeads() -> AnyPublisher<[Lead], Error> {
        Just(mockLeads)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func addLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        Just(lead)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        Just(lead)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func deleteLead(id: UUID) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
