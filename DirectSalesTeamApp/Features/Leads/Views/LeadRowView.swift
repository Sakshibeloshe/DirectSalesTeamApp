import SwiftUI

struct LeadRowView: View {
    let lead: Lead
    var isNew: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with dynamic background
            AvatarView(
                initials: lead.initials,
                color: lead.name.avatarColor,
                size: 42
            )
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    let displayName = lead.name.count < 10 || !lead.name.allSatisfy({ $0.isHexDigit }) ? lead.name : "Pending Registration"
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    
                    if lead.status == .new || isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                HStack(spacing: 6) {
                    Text(lead.loanType.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                    
                    Text("•")
                        .foregroundColor(Color.textTertiary)
                    
                    Text(lead.formattedAmount)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.brandBlue)
                    
                    Spacer()
                    
                    Text(lead.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textTertiary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.textTertiary.opacity(0.5))
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfacePrimary)
        .contentShape(Rectangle())
    }
}

// MARK: - Swipeable Row Wrapper
struct SwipeableLeadRow: View {
    let lead: Lead
    var onCall: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        LeadRowView(lead: lead)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDelete?()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onCall?()
                } label: {
                    Label("Call", systemImage: "phone.fill")
                }
                .tint(Color.statusApproved)
            }
    }
}
