import SwiftUI

@MainActor
struct ApplicationsView: View {
    @ObservedObject var viewModel: ApplicationsViewModel

    // Maps ApplicationStatus → display title for filter chips
    private let filterStatuses: [(label: String, status: ApplicationStatus?)] = [
        ("All", nil),
        ("Submitted", .submitted),
        ("Officer Review", .officerReview),
        ("Officer Approved", .officerApproved),
        ("Manager Review", .managerReview),
        ("Sanctioned", .managerApproved),
        ("Approved", .approved),
        ("Rejected", .rejected),
        ("Disbursed", .disbursed),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                VStack(spacing: 0) {
                    // Compact summary strip
                    HStack(spacing: AppSpacing.md) {
                        summaryItem(label: "Total", value: "\(viewModel.stats.total)")
                        summaryItem(label: "In Review", value: "\(viewModel.stats.inReview)")
                        summaryItem(label: "Approved", value: "\(viewModel.stats.approved)")
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)

                    SearchBarView(text: $viewModel.searchText)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xs)

                    filterChipHeader
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            if viewModel.isLoading && viewModel.applications.isEmpty {
                                shimmerLoadingView
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
            }
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

    private func summaryItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.textSecondary)
        }
    }

    // MARK: - FILTER CHIP HEADER WITH CHEVRONS
    private var filterChipHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(filterStatuses, id: \.label) { item in
                    let count = item.status == nil ? viewModel.stats.total : countFor(item.status!)
                    if count > 0 || item.status == nil {
                        chipView(for: item)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    gradient: Gradient(colors: [.black, .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
        )
    }

    // MARK: - CHIP VIEW (NO SHRINK, INSTANT RESPONSE)
    private func chipView(for item: (label: String, status: ApplicationStatus?)) -> some View {
        let isSelected = viewModel.selectedStatus == item.status

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.selectStatus(item.status)
        } label: {
            HStack(spacing: 5) {
                Text(item.label)
                    .font(AppFont.subheadMed())

                let count = item.status == nil
                    ? viewModel.stats.total
                    : countFor(item.status!)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : Color.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.surfaceTertiary)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brandBlue : Color.surfacePrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.brandBlue : Color.borderLight, lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.brandBlue.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func countFor(_ status: ApplicationStatus) -> Int {
        switch status {
        case .submitted:       return viewModel.applications.filter { $0.status == .submitted }.count
        case .officerReview:   return viewModel.applications.filter { $0.status == .officerReview }.count
        case .officerApproved: return viewModel.applications.filter { $0.status == .officerApproved }.count
        case .managerReview:   return viewModel.applications.filter { $0.status == .managerReview }.count
        case .managerApproved: return viewModel.applications.filter { $0.status == .managerApproved }.count
        case .approved:        return viewModel.applications.filter { $0.status == .approved }.count
        case .rejected:        return viewModel.applications.filter { $0.status == .rejected }.count
        case .disbursed:       return viewModel.stats.disbursed
        }
    }

    // MARK: - Application List
    private var applicationList: some View {
        LazyVStack(spacing: 0) {
            Color.clear.frame(height: 1).id("top_anchor")
            ForEach(viewModel.filteredApplications) { app in
                NavigationLink(value: app) {
                    ApplicationRowView(application: app)
                }
                .buttonStyle(.plain)
                
                if app.id != viewModel.filteredApplications.last?.id {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Loading
    private var shimmerLoadingView: some View {
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

// MARK: - Detail Placeholder (expand in next sprint)
struct ApplicationDetailPlaceholder: View {
    let application: LoanApplication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header card
                    VStack(spacing: AppSpacing.sm) {
                        AvatarView(
                            initials: application.initials,
                            color: application.name.avatarColor,
                            size: 64
                        )
                        Text(application.name)
                            .font(AppFont.title2())
                            .foregroundColor(Color.textPrimary)
                        ApplicationStatusBadge(status: application.status)
                        Text("\(application.loanType.rawValue)  ·  \(application.formattedAmount)")
                            .font(AppFont.body())
                            .foregroundColor(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Pipeline
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Pipeline Status")
                            .font(AppFont.headline())
                            .foregroundColor(Color.textPrimary)

                        PipelineProgressBar(application: application)
                            .padding(.vertical, AppSpacing.xs)

                        HStack {
                            ForEach(LoanApplication.pipeline) { stage in
                                Text(stage.label)
                                    .font(AppFont.caption())
                                    .foregroundColor(Color.textTertiary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Info rows
                    VStack(spacing: 0) {
                        detailRow(label: "Bank", value: application.bankName ?? "—")
                        Divider().padding(.leading, AppSpacing.md)
                        detailRow(label: "RM Assigned", value: application.rmName ?? "—")
                        Divider().padding(.leading, AppSpacing.md)
                        detailRow(label: "Status Note", value: application.statusLabel)
                        if let sanctioned = application.sanctionedAmount {
                            Divider().padding(.leading, AppSpacing.md)
                            detailRow(label: "Sanctioned", value: formatAmount(sanctioned))
                        }
                        if let disbursed = application.disbursedAmount {
                            Divider().padding(.leading, AppSpacing.md)
                            detailRow(label: "Disbursed", value: formatAmount(disbursed))
                        }
                    }
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    Text("Full detail view — next sprint")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                }
                .padding(AppSpacing.md)
            }
            .background(Color.surfaceSecondary.ignoresSafeArea())
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.subheadMed())
                .foregroundColor(Color.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private func formatAmount(_ v: Double) -> String {
        let lakhs = v / 100_000
        return lakhs >= 100
            ? "₹\(String(format: "%.0f", lakhs / 100))Cr"
            : "₹\(Int(lakhs))L"
    }
}

#Preview {
    ApplicationsView(viewModel: ApplicationsViewModel())
}
