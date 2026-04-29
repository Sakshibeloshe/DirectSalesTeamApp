import SwiftUI

@MainActor
struct ApplicationsView: View {
    @ObservedObject var viewModel: ApplicationsViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                VStack(spacing: 0) {
                    applicationsHero
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    stickyHeader

                    applicationListContent
                }
                .padding(.top, -8)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LoanApplication.self) { app in
                ApplicationDetailView(application: app)
            }
            .refreshable {
                viewModel.loadApplications()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dstDataChanged)) { _ in
                viewModel.loadApplications()
            }
        }
    }

    private var applicationsHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Application Pipeline", subtitle: "Track every converted file with the same transparency and confidence as the borrower experience.")
                HStack(spacing: AppSpacing.sm) {
                    statTile(title: "Total", value: "\(viewModel.stats.total)", color: Color.textPrimary)
                    statTile(title: "In Review", value: "\(viewModel.stats.inReview)", color: Color.statusPending)
                    statTile(title: "Approved", value: "\(viewModel.stats.approved)", color: Color.statusApproved)
                }
            }
        }
    }

    private func statTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.title2())
                .foregroundColor(color)
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.brandBlueSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    // MARK: - Sticky Header
    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                SearchBarView(text: $viewModel.searchText)
                
                Menu {
                    ForEach(ApplicationStatus.allCases) { status in
                        Button {
                            viewModel.selectStatus(status)
                        } label: {
                            Label {
                                Text(status.displayName)
                            } icon: {
                                if viewModel.selectedStatus == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brandBlue)
                        .frame(width: 44, height: 44)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.borderLight, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
        .padding(.bottom, AppSpacing.sm)
        .background(Color.clear)
    }

    // MARK: - List Content
    @ViewBuilder
    private var applicationListContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.isLoading && viewModel.applications.isEmpty {
                    loadingView
                } else if viewModel.filteredApplications.isEmpty {
                    emptyView
                } else {
                    applicationList
                        .padding(.top, AppSpacing.sm)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DSTScrollToTop"))) { note in
                if let index = note.object as? Int, index == 1 { // 1 is Apps tab
                    withAnimation(.spring()) {
                        proxy.scrollTo("top_anchor", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Application List
    private var applicationList: some View {
        LazyVStack(spacing: 0) {
            Color.clear.frame(height: 1).id("top_anchor")
            
            ForEach(Array(viewModel.filteredApplications.enumerated()), id: \.element.id) { index, app in
                NavigationLink(value: app) {
                    ApplicationRowView(application: app)
                }
                .buttonStyle(.plain)
                
                if index < viewModel.filteredApplications.count - 1 {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Loading
    private var loadingView: some View {
        DSTSkeletonList()
            .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Empty
    private var emptyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.surfaceTertiary).frame(width: 72, height: 72)
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            VStack(spacing: AppSpacing.xs) {
                Text(viewModel.selectedStatus != nil
                     ? "No \(viewModel.selectedStatus!.rawValue) applications"
                     : "No applications yet")
                    .font(AppFont.headline())
                    .foregroundColor(Color.textPrimary)
                Text("Applications converted from leads will appear here.")
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }
            Spacer()
        }
    }
}

// MARK: - Row View (Already exists in project, but including if needed or mapping to existing)
// Note: Assuming ApplicationRowView is already defined in the project as used in the previous version.

#Preview {
    ApplicationsView(viewModel: ApplicationsViewModel())
}
