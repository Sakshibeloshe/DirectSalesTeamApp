import SwiftUI

struct ApplicationsView: View {
    @StateObject private var viewModel = ApplicationsViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Stats bar (tappable — filters list) ──
                    ApplicationStatsBar(stats: viewModel.stats) { tappedStatus in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Tap same stat to deselect (back to All)
                            viewModel.selectStatus(
                                viewModel.selectedStatus == tappedStatus ? nil : tappedStatus
                            )
                        }
                    }

                    topDivider

                    // ── Active filter pill (shown when a stat is tapped) ──
                    if let active = viewModel.selectedStatus {
                        activeFilterBanner(status: active)
                    }

                    // ── List ──
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.filteredApplications.isEmpty {
                        emptyView
                    } else {
                        applicationList
                    }
                }
            }
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarDots }
            .sheet(item: $viewModel.selectedApplication) { app in
                ApplicationDetailPlaceholder(application: app)
            }
            .refreshable {
                viewModel.loadApplications()
            }
        }
    }

    // MARK: - Stats → list divider
    private var topDivider: some View {
        Rectangle()
            .fill(Color.borderLight)
            .frame(height: 1)
    }

    // MARK: - Active filter banner
    private func activeFilterBanner(status: ApplicationStatus) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 7, height: 7)
            Text("Showing: \(status.rawValue)")
                .font(AppFont.subheadMed())
                .foregroundColor(status.textColor)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectStatus(nil)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Clear")
                        .font(AppFont.captionMed())
                }
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.surfaceTertiary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs + 2)
        .background(status.backgroundColor)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Application List
    private var applicationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredApplications.enumerated()), id: \.element.id) { index, app in
                    ApplicationRowView(application: app) {
                        viewModel.selectedApplication = app
                    }
                    if index < viewModel.filteredApplications.count - 1 {
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
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(Color.brandBlue)
            Text("Loading applications…")
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
        }
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

    // MARK: - Toolbar dots (matching screenshot)
    @ToolbarContentBuilder
    private var toolbarDots: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 6) {
                ForEach(
                    [Color(hex: "#F87171"),
                     Color(hex: "#60A5FA"),
                     Color(hex: "#34D399"),
                     Color(hex: "#F87171")],
                    id: \.self
                ) { color in
                    Circle().fill(color).frame(width: 10, height: 10)
                }
            }
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
    ApplicationsView()
}
