import SwiftUI

@MainActor
struct ContentView: View {
    @State private var selectedTab: Tab = .leads

    enum Tab: Int, CaseIterable {
        case leads        = 0
        case applications = 1
        case messages     = 2
        case earnings     = 3
        case profile      = 4
    }

    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab {
                    NotificationCenter.default.post(name: Notification.Name("DSTScrollToTop"), object: newValue.rawValue)
                }
                selectedTab = newValue
            }
        )
    }

    // Shared state injected here and passed down as needed
    @StateObject private var leadsViewModel        = LeadsViewModel()
    @StateObject private var applicationsViewModel = ApplicationsViewModel()
    @StateObject private var messagesViewModel     = MessagesViewModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.surfacePrimary)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.brandBlue)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.brandBlue)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.textTertiary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: tabSelection) {

            // ── Tab 1: Leads ──
            LeadsView(viewModel: leadsViewModel)
                .tabItem {
                    Label("Leads", systemImage: selectedTab == .leads
                          ? "person.crop.circle.fill.badge.plus"
                          : "person.crop.circle.badge.plus")
                }
                .tag(Tab.leads)

            // ── Tab 2: Applications ──
            ApplicationsView(viewModel: applicationsViewModel)
                .tabItem {
                    Label("Applications", systemImage: selectedTab == .applications
                          ? "doc.plaintext.fill"
                          : "doc.plaintext")
                }
                .tag(Tab.applications)

            // ── Tab 3: Messages ──
            MessagesView(vm: messagesViewModel)
                .tabItem {
                    Label("Messages", systemImage: selectedTab == .messages
                          ? "message.fill"
                          : "message")
                }
                .tabBadge(messagesViewModel.totalUnread)
                .tag(Tab.messages)

            // ── Tab 4: Earnings ──
            EarningsView()
                .tabItem {
                    Label("Earnings", systemImage: selectedTab == .earnings
                          ? "banknote.fill"
                          : "banknote")
                }
                .tag(Tab.earnings)

            // ── Tab 5: Profile ──
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == .profile
                          ? "person.circle.fill"
                          : "person.circle")
                }
                .tag(Tab.profile)
        }
        .tint(Color.brandBlue)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DSTSwitchTab"))) { note in
            if let index = note.object as? Int, let tab = Tab(rawValue: index) {
                selectedTab = tab
            }
        }
    }
}

#Preview {
    ContentView()
}
