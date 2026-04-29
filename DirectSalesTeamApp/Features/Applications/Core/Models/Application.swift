import SwiftUI

// MARK: - Application Status
enum ApplicationStatus: String, CaseIterable, Identifiable, Codable {
    case submitted       = "Submitted"
    case officerReview   = "Officer Review"
    case officerApproved = "Officer Approved"
    case managerReview   = "Manager Review"
    case managerApproved = "Sanctioned"
    case approved        = "Approved"
    case rejected        = "Rejected"
    case disbursed       = "Disbursed"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var dotColor: Color {
        switch self {
        case .submitted:       return .statusSubmitted
        case .officerReview:   return .statusPending
        case .officerApproved: return .brandBlue
        case .managerReview:   return Color(hex: "#F59E0B")
        case .managerApproved: return Color(hex: "#0F9D84")
        case .approved:        return .statusApproved
        case .rejected:        return .statusRejected
        case .disbursed:       return .statusDisbursed
        }
    }

    var textColor: Color { dotColor }

    var backgroundColor: Color {
        switch self {
        case .submitted:       return .statusSubmittedBg
        case .officerReview:   return .statusPendingBg
        case .officerApproved: return Color.brandBlue.opacity(0.12)
        case .managerReview:   return Color(hex: "#F59E0B").opacity(0.14)
        case .managerApproved: return Color(hex: "#0F9D84").opacity(0.14)
        case .approved:        return .statusApprovedBg
        case .rejected:        return .statusRejectedBg
        case .disbursed:       return .statusDisbursedBg
        }
    }

    // Which pipeline step index this status corresponds to (0-based)
    var pipelineStep: Int {
        switch self {
        case .submitted:       return 1
        case .officerReview:   return 2
        case .officerApproved: return 2
        case .managerReview:   return 2
        case .managerApproved: return 3
        case .approved:        return 3
        case .rejected:        return 2
        case .disbursed:       return 4
        }
    }
}

// MARK: - Pipeline Stage
struct PipelineStage: Identifiable {
    let id: Int
    let label: String
}

// MARK: - Application Model
struct LoanApplication: Identifiable, Codable, Hashable {
    let id: String
    var leadId: String?
    var name: String
    var phone: String
    var referenceNumber: String?
    var loanType: LoanType
    var loanAmount: Double
    var status: ApplicationStatus
    var createdAt: Date
    var updatedAt: Date
    var slaDays: Int?           // days remaining for current stage
    var statusLabel: String     // e.g. "2 days left", "Disbursement pending", "Closed", "Completed"
    var bankName: String?
    var sanctionedAmount: Double?
    var disbursedAmount: Double?
    var rmName: String?

    // MARK: - Computed
    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var formattedAmount: String {
        let lakhs = loanAmount / 100_000
        if lakhs >= 100 {
            return "₹\(String(format: "%.0f", lakhs / 100))Cr"
        } else if loanAmount.truncatingRemainder(dividingBy: 100_000) == 0 {
            return "₹\(Int(lakhs))L"
        } else {
            return "₹\(String(format: "%.1f", lakhs))L"
        }
    }

    var displayName: String {
        if name.hasPrefix("LMS-") || name == referenceNumber {
            return "\(loanType.rawValue) · \(formattedAmount)"
        }
        return name
    }

    // All 5 pipeline stages
    static let pipeline: [PipelineStage] = [
        PipelineStage(id: 0, label: "Applied"),
        PipelineStage(id: 1, label: "Submitted"),
        PipelineStage(id: 2, label: "Review"),
        PipelineStage(id: 3, label: "Approved"),
        PipelineStage(id: 4, label: "Disbursed"),
    ]
}

// MARK: - Applications Summary Stats
struct ApplicationStats {
    let total: Int
    let inReview: Int
    let approved: Int
    let disbursed: Int
}
