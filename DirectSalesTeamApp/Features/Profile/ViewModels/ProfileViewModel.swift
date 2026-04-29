// MARK: - ProfileViewModel.swift
// ViewModel for the Profile tab and all push screens

import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published

    @Published var agent: DSTAgent = DSTAgent(
        id: UUID(),
        firstName: "—",
        lastName: "",
        zone: "—",
        city: "—",
        agentCode: "—",
        tier: .junior,
        nbfcLicense: "—",
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
        avatarColor: "7B8FD4",
        trustScore: 0,
        totalLeads: 0,
        approvalRate: 0.0,
        rejectionRate: 0.0,
        zoneRank: 0,
        zoneRankMonth: "",
        totalZoneAgents: 0
    )
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var isLoading: Bool = false
    @Published var isUsingMockData: Bool = false
    @Published var showLogoutConfirm: Bool = false
    @Published var errorMessage: String? = nil

    // Push screen navigation triggers
    @Published var showNotificationSettings: Bool = false
    @Published var showSecuritySettings: Bool = false
    @Published var showPrivacy: Bool = false
    @Published var showHelpCenter: Bool = false
    @Published var showContactSupport: Bool = false
    @Published var showTerms: Bool = false

    // MARK: - Computed

    var trustScoreColor: Color {
        switch agent.trustScore {
        case 80...100: return Color(red: 0.12, green: 0.35, blue: 0.75)
        case 60...79:  return .orange
        default:       return .red
        }
    }

    var trustScoreProgress: Double { Double(agent.trustScore) / 100.0 }

    var performanceSummary: String {
        "\(agent.approvalRatePercent)% approval · \(agent.totalLeads) leads"
    }

    var topPerformerText: String {
        "Top Performer — \(agent.zoneRankMonth)"
    }

    var rankText: String {
        guard agent.zoneRank > 0 else { return "" }
        return "Ranked #\(agent.zoneRank) in \(agent.zone)"
    }

    var settingsItems: [(section: SettingsSection, items: [SettingsItem])] {
        let grouped = Dictionary(grouping: SettingsItem.allCases, by: \.section)
        return [
            (.settings, grouped[.settings] ?? []),
            (.support,  grouped[.support]  ?? [])
        ]
    }

    var footerText: String {
        "DST Agent v\(agent.appVersion) · NBFC License: \(agent.nbfcLicense)"
    }

    // MARK: - Actions

    func loadProfile() async {
        isLoading = true
        isUsingMockData = false
        defer { isLoading = false }

        do {
            // Fetch profile via AuthService.GetMyProfile (authenticated)
            let authClient = AuthGRPCClient()
            guard let token = try? TokenStore.shared.accessToken() else {
                isUsingMockData = true
                return
            }
            let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
            let response = try await authClient.getMyProfile(
                request: Auth_V1_GetMyProfileRequest(),
                metadata: metadata,
                options: options
            )

            // Extract DST profile from the oneof
            guard case .dstProfile(let dst) = response.profile else {
                isUsingMockData = true
                return
            }

            // Parse name parts
            let nameParts = dst.name.split(separator: " ").map(String.init)
            let firstName = nameParts.first ?? dst.name
            let lastName  = nameParts.dropFirst().joined(separator: " ")

            agent = DSTAgent(
                id: UUID(uuidString: response.userID) ?? UUID(),
                firstName: firstName,
                lastName: lastName,
                zone: dst.branch.region,
                city: dst.branch.city,
                agentCode: dst.profileID,
                tier: .junior,               // derive from profile data if available
                nbfcLicense: "—",            // not in DST profile — placeholder
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
                avatarColor: "7B8FD4",
                trustScore: 0,               // placeholder — derive from lead stats separately
                totalLeads: 0,               // fetch from lead count separately
                approvalRate: 0.0,
                rejectionRate: 0.0,
                zoneRank: 0,
                zoneRankMonth: "",
                totalZoneAgents: 0
            )
            isUsingMockData = false

        } catch {
            errorMessage = error.localizedDescription
            isUsingMockData = true
        }
    }

    func handleSettingsTap(_ item: SettingsItem) {
        switch item {
        case .notifications:   showNotificationSettings = true
        case .securityPin:     showSecuritySettings = true
        case .privacy:         showPrivacy = true
        case .helpCenter:      showHelpCenter = true
        case .contactSupport:  showContactSupport = true
        case .termsCompliance: showTerms = true
        }
    }

    func confirmLogout() { showLogoutConfirm = true }

    func saveNotificationSettings() {
        // TODO: PATCH /api/agent/notification-settings
    }
}
