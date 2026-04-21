import SwiftUI

// MARK: - Application Status
enum ApplicationStatus: String, CaseIterable, Identifiable, Codable {
    case submitted    = "Submitted"
    case underReview  = "Under Review"
    case approved     = "Approved"
    case rejected     = "Rejected"
    case disbursed    = "Disbursed"

    var id: String { rawValue }

    var dotColor: Color {
        switch self {
        case .submitted:   return Color(hex: "#2563EB")
        case .underReview: return Color(hex: "#D97706")
        case .approved:    return Color(hex: "#057A55")
        case .rejected:    return Color(hex: "#C81E1E")
        case .disbursed:   return Color(hex: "#057A55")
        }
    }

    var textColor: Color { dotColor }

    var backgroundColor: Color {
        switch self {
        case .submitted:   return Color(hex: "#EBF0FF")
        case .underReview: return Color(hex: "#FDF6EC")
        case .approved:    return Color(hex: "#E8F5EF")
        case .rejected:    return Color(hex: "#FEF2F2")
        case .disbursed:   return Color(hex: "#E8F5EF")
        }
    }

    // Which pipeline step index this status corresponds to (0-based)
    var pipelineStep: Int {
        switch self {
        case .submitted:   return 1
        case .underReview: return 2
        case .approved:    return 3
        case .rejected:    return 2   // stalls at review
        case .disbursed:   return 4
        }
    }
}

// MARK: - Pipeline Stage
struct PipelineStage: Identifiable {
    let id: Int
    let label: String
}

// MARK: - Application Model
struct LoanApplication: Identifiable, Codable {
    let id: UUID
    var leadId: UUID?
    var name: String
    var phone: String
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
    let underReview: Int
    let approved: Int
    let disbursed: Int
}
