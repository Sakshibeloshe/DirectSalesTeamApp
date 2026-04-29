import SwiftUI

// MARK: - Application Detail View (DST)
/// Rich status-tracker view for a submitted loan application.
/// Mirrors the borrower-side ActiveLoanDetailsView but shows application pipeline
/// stages (not EMI/repayment data) since DST manages pre-disbursement stages.
struct ApplicationDetailView: View {
    let application: LoanApplication

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceSecondary.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    headerCard
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        DSTSectionTitle("Application Pipeline")
                        statusTimelineCard
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        DSTSectionTitle("Lending Details")
                        infoCard
                    }
                    
                    commissionCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .navigationTitle("Application Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card
    private var headerCard: some View {
        DSTSurfaceCard {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    AvatarView(
                        initials: application.initials,
                        color: application.name.avatarColor,
                        size: 64
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(application.name)
                            .font(AppFont.title2())
                            .foregroundColor(Color.textPrimary)
                        
                        if let ref = application.referenceNumber, !ref.isEmpty {
                            Text(ref)
                                .font(AppFont.caption())
                                .foregroundColor(Color.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.surfaceSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    ApplicationStatusBadge(status: application.status)
                }
                
                Divider()
                
                HStack {
                    detailItem(title: "Loan Type", value: application.loanType.rawValue, icon: application.loanType.icon)
                    Spacer()
                    detailItem(title: "Total Amount", value: application.formattedAmount, icon: "indianrupeesign.circle")
                }
            }
        }
    }

    private func detailItem(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color.brandBlue)
                .frame(width: 32, height: 32)
                .background(Color.brandBlue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.caption())
                    .foregroundColor(Color.textSecondary)
                Text(value)
                    .font(AppFont.subheadMed())
                    .foregroundColor(Color.textPrimary)
            }
        }
    }

    // MARK: - Status Timeline Card
    private var statusTimelineCard: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ApplicationPipelineStage.allCases.enumerated()), id: \.element) { idx, stage in
                    let stageState = stateFor(stage)
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(dotBackground(for: stageState))
                                    .frame(width: 24, height: 24)

                                iconFor(stageState)
                            }

                            if idx < ApplicationPipelineStage.allCases.count - 1 {
                                Rectangle()
                                    .fill(lineColor(for: idx + 1))
                                    .frame(width: 2, height: 32)
                            }
                        }
                        .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.title)
                                .font(stageState == .active ? AppFont.bodyMedium() : AppFont.body())
                                .foregroundColor(stageState == .pending ? Color.textTertiary : Color.textPrimary)

                            Text(stage.subtitle(for: application.status))
                                .font(AppFont.caption())
                                .foregroundColor(stageState == .active ? Color.brandBlue : (stageState == .rejected ? Color.statusRejected : Color.textTertiary))
                        }
                        .padding(.bottom, idx == ApplicationPipelineStage.allCases.count - 1 ? 0 : 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Info Card
    private var infoCard: some View {
        DSTSurfaceCard {
            VStack(spacing: 0) {
                infoRow("Bank / Branch", application.bankName ?? "—", icon: "building.2")
                Divider().padding(.leading, 44)
                infoRow("RM Assigned", application.rmName ?? "—", icon: "person.badge.shield.checkered")
                Divider().padding(.leading, 44)
                infoRow("Submitted On", formattedDate(application.createdAt), icon: "calendar")
                
                if let sanctioned = application.sanctionedAmount {
                    Divider().padding(.leading, 44)
                    infoRow("Sanctioned", formatAmount(sanctioned), icon: "checkmark.seal")
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                Text(value)
                    .font(AppFont.subheadMed())
                    .foregroundColor(Color.textPrimary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Commission Card
    private var commissionCard: some View {
        DSTSurfaceCard {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Commission")
                        .font(AppFont.subheadMed())
                        .foregroundColor(Color.textPrimary)
                    Text(estimatedCommission)
                        .font(AppFont.title2())
                        .foregroundColor(Color.brandBlue)
                    Text("Payable within 30 days of disbursement")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Helpers (Logic)
    private func iconFor(_ state: StageState) -> some View {
        Group {
            switch state {
            case .completed: Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
            case .active: Circle().fill(Color.brandBlue).frame(width: 8, height: 8)
            case .rejected: Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
            case .pending: EmptyView()
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }

    private func formatAmount(_ v: Double) -> String {
        let lakhs = v / 100_000
        if lakhs >= 100 { return "₹\(String(format: "%.1f", lakhs / 100)) Cr" }
        return "₹\(Int(lakhs)) L"
    }

    private var estimatedCommission: String {
        formatAmount(application.loanAmount * 0.0025)
    }

    enum StageState { case completed, active, rejected, pending }

    private func stateFor(_ stage: ApplicationPipelineStage) -> StageState {
        let currentStep = application.status.pipelineStep
        let stageStep = stage.step
        if (application.status == .rejected) && stage == .review { return .rejected }
        if stageStep < currentStep  { return .completed }
        if stageStep == currentStep { return .active }
        return .pending
    }

    private func dotBackground(for state: StageState) -> Color {
        switch state {
        case .completed: return Color.brandBlue
        case .active: return Color.brandBlue.opacity(0.15)
        case .rejected: return Color.statusRejected
        case .pending: return Color(.systemGray5)
        }
    }

    private func lineColor(for stageIndex: Int) -> Color {
        let stage = ApplicationPipelineStage.allCases[stageIndex]
        let s = stateFor(stage)
        return (s == .completed || s == .active) ? Color.brandBlue : Color(.systemGray5)
    }
}

// MARK: - Pipeline Stage Enum (DST view)
enum ApplicationPipelineStage: CaseIterable, Hashable {
    case applied, submitted, review, approved, disbursed

    var step: Int {
        switch self {
        case .applied:   return 0
        case .submitted: return 1
        case .review:    return 2
        case .approved:  return 3
        case .disbursed: return 4
        }
    }

    var title: String {
        switch self {
        case .applied:   return "Applied"
        case .submitted: return "Submitted"
        case .review:    return "Under Review"
        case .approved:  return "Approved"
        case .disbursed: return "Disbursed"
        }
    }

    func subtitle(for status: ApplicationStatus) -> String {
        switch self {
        case .applied: return "Application created"
        case .submitted: return status.pipelineStep >= 1 ? "Submitted for review" : "Awaiting submission"
        case .review:
            if status == .rejected { return "Application rejected" }
            switch status {
            case .officerReview: return "Under officer review"
            case .officerApproved: return "Officer approved, waiting for manager"
            case .managerReview: return "Under manager review"
            default: return status.pipelineStep >= 2 ? "Under review by team" : "Not yet started"
            }
        case .approved:
            switch status {
            case .managerApproved: return "Loan sanctioned ✓"
            case .approved: return "Loan approved ✓"
            default: return status.pipelineStep >= 3 ? "Loan sanctioned ✓" : "Pending approval"
            }
        case .disbursed: return status.pipelineStep >= 4 ? "Funds disbursed ✓" : "Awaiting disbursement"
        }
    }
}
