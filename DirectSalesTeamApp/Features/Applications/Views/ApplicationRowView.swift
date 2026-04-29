import SwiftUI

struct ApplicationRowView: View {
    let application: LoanApplication
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {

                // Avatar
                AvatarView(
                    initials: application.initials,
                    color: application.name.avatarColor,
                    size: 48
                )
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Row 1: Name + Status badge
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        Text(application.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        ApplicationStatusBadge(status: application.status)
                            .scaleEffect(0.85)
                    }

                    // Row 2: Type + Amount
                    HStack(spacing: 6) {
                        Text(application.loanType.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                        Text("•")
                            .foregroundColor(Color.textTertiary)
                        Text(application.formattedAmount)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.brandBlue)
                    }

                    // Row 3: Pipeline progress bar
                    PipelineProgressBar(application: application)
                        .padding(.top, 2)

                    // Row 4: Status label
                    statusLabelView
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(Color.surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status label row
    @ViewBuilder
    private var statusLabelView: some View {
        HStack(spacing: 5) {
            // Icon based on status
            if application.status == .rejected {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusRejected)
            } else if application.status == .disbursed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusDisbursed)
            } else if let days = application.slaDays, days <= 2 {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusPending)
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color.textTertiary)
            }

            Text(application.statusLabel)
                .font(AppFont.caption())
                .foregroundColor(statusLabelColor)
        }
    }

    private var statusLabelColor: Color {
        switch application.status {
        case .rejected:        return Color.statusRejected
        case .disbursed:       return Color.statusDisbursed
        case .officerReview, .managerReview:
            if let days = application.slaDays, days <= 2 { return Color.statusPending }
            return Color.textSecondary
        case .officerApproved:
            return Color.brandBlue
        case .managerApproved:
            return Color(hex: "#0F9D84")
        default:
            return Color.textSecondary
        }
    }
}

#Preview {
    let sample = LoanApplication(
        id: UUID().uuidString, leadId: nil, name: "Rohit Verma", phone: "9900112233",
        referenceNumber: "APP-1001",
        loanType: .business, loanAmount: 5_000_000, status: .officerReview,
        createdAt: Date(), updatedAt: Date(), slaDays: 2, statusLabel: "2 days left",
        bankName: "HDFC", sanctionedAmount: nil, disbursedAmount: nil, rmName: "Vikram"
    )
    ApplicationRowView(application: sample)
        .padding()
}
