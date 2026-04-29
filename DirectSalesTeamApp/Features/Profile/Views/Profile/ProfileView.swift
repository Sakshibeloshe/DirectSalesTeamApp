// MARK: - ProfileView.swift
// Profile tab — matches design from screenshots
// Pushes: NotificationSettingsView, SecuritySettingsView, PrivacyView,
//         HelpCenterView, ContactSupportView, TermsView

import SwiftUI

struct ProfileView: View {

    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                ScrollView {
                    VStack(spacing: 0) {
                        agentHeaderSection
                        performanceSection
                        topPerformerBanner
                        settingsList
                        logoutButton
                        footerLabel
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            // Push destinations
            .navigationDestination(isPresented: $vm.showNotificationSettings) {
                NotificationSettingsView(vm: vm)
            }
            .navigationDestination(isPresented: $vm.showSecuritySettings) {
                SecuritySettingsView()
                    .environmentObject(session)
            }
            .navigationDestination(isPresented: $vm.showPrivacy) {
                PrivacyView()
            }
            .navigationDestination(isPresented: $vm.showHelpCenter) {
                HelpCenterView()
            }
            .navigationDestination(isPresented: $vm.showContactSupport) {
                ContactSupportView()
            }
            .navigationDestination(isPresented: $vm.showTerms) {
                TermsView()
            }
            .confirmationDialog("Log out of DST Agent?", isPresented: $vm.showLogoutConfirm, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) {
                    vm.showLogoutConfirm = false
                    session.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                if #available(iOS 18.0, *) {
                    await vm.loadProfile()
                }
            }
        }
    }

    // MARK: - Agent Header

    private var agentHeaderSection: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.88, blue: 0.97))
                    .frame(width: 60, height: 60)
                Text(vm.agent.initials)
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.28, green: 0.4, blue: 0.78))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.agent.fullName)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Color(.label))
                Text(vm.agent.displayZone)
                    .font(.subheadline).foregroundStyle(.secondary)
                TierBadge(tier: vm.agent.tier)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Performance Card

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PERFORMANCE")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if vm.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Syncing...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if vm.isUsingMockData {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Stats unavailable")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 0) {
                // Top row: Trust score ring + stats
                HStack(spacing: 0) {
                    // Trust score ring
                    VStack(spacing: 6) {
                        TrustScoreRing(score: vm.agent.trustScore, color: vm.trustScoreColor)
                        Text("Trust Score")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    Divider().frame(height: 80)

                    // Stats
                    VStack(alignment: .leading, spacing: 8) {
                        if vm.isUsingMockData || vm.isLoading {
                            Text("—")
                                .font(.title).fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(vm.agent.totalLeads)")
                                .font(.title).fontWeight(.bold)
                        }
                        Text("Total Leads")
                            .font(.caption).foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                if vm.isUsingMockData || vm.isLoading {
                                    Text("—")
                                        .font(.headline).fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(vm.agent.approvalRatePercent)%")
                                        .font(.headline).fontWeight(.bold)
                                        .foregroundStyle(Color(red: 0.12, green: 0.35, blue: 0.75))
                                }
                                Text("Approval")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if vm.isUsingMockData || vm.isLoading {
                                    Text("—")
                                        .font(.headline).fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(vm.agent.rejectionRatePercent)%")
                                        .font(.headline).fontWeight(.bold)
                                        .foregroundStyle(.red)
                                }
                                Text("Rejection")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                    .padding(.leading, 20)
                }
            }
            .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .cardShadow()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Top Performer Banner

    private var topPerformerBanner: some View {
        Group {
            if vm.agent.isTopPerformer && vm.agent.totalLeads > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.12, green: 0.35, blue: 0.75))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.topPerformerText)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color(red: 0.12, green: 0.35, blue: 0.75))
                        Text(vm.rankText)
                            .font(.caption).foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.85))
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                .padding(16)
                .background(Color.brandBlueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.brandBlue.opacity(0.12), lineWidth: 1)
                )
                .cardShadow()
                .padding(.horizontal, 16)
                .padding(.top, 12)
            } else if vm.agent.totalLeads == 0 {
                // Onboarding card
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock your ranking")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Complete your first lead to build your score.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.borderLight, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Settings List

    private var settingsList: some View {
        VStack(spacing: 0) {
            ForEach(vm.settingsItems, id: \.section) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.section.rawValue)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(group.items) { item in
                            SettingsRow(item: item) {
                                vm.handleSettingsTap(item)
                            }
                            if item != group.items.last {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.borderLight, lineWidth: 1)
                    )
                    .cardShadow()
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button(action: vm.confirmLogout) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "arrow.right.square")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                Text("Log Out")
                    .font(.body).fontWeight(.medium)
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(16)
            .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .cardShadow()
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerLabel: some View {
        VStack(spacing: 4) {
            Text(vm.footerText)
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
            Spacer().frame(height: 100) // Safe area padding
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Sub-components

struct TierBadge: View {
    let tier: AgentTier
    var body: some View {
        Text("DST Agent · \(tier.rawValue)")
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(tier.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tier.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(tier.color.opacity(0.3), lineWidth: 1))
    }
}

struct TrustScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            if score == 0 {
                // Dashed ring for unearned state — not a failure, just unstarted
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 8, dash: [6, 4]))
                        .foregroundColor(Color.borderMedium)
                        .frame(width: 80, height: 80)
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.textTertiary)
                        Text("NEW")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.textTertiary)
                            .tracking(0.5)
                    }
                }
            } else {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: score)

                VStack(spacing: 1) {
                    Text("\(score)")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(color)
                    Text("TRUST")
                        .font(.system(size: 9)).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }
            }
        }
    }
}

struct SettingsRow: View {
    let item: SettingsItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.body)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview { ProfileView() }
