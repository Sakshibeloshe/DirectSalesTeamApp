import SwiftUI

struct LeadsView: View {
    @StateObject private var viewModel = LeadsViewModel()
    @State private var navPath = NavigationPath()
    @State private var showDeleteConfirm = false
    @State private var leadToDelete: Lead? = nil

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()

                VStack(spacing: 0) {
                    stickyHeader

                    if !viewModel.isLoading {
                        HStack {
                            Text(viewModel.leadCountText)
                                .font(AppFont.subhead())
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xs)
                    }

                    leadListContent
                }
            }
            .navigationTitle("Leads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showAddLead = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Add Lead")
                                .font(AppFont.subheadMed())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.brandBlue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            // ── Add Lead modal — always bottom sheet, never iPad popup ──
            .sheet(isPresented: $viewModel.showAddLead) {
                AddLeadView(viewModel: viewModel)
                    .presentationDetents([.height(560), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
                    .presentationContentInteraction(.scrolls)
                    .presentationCompactAdaptation(.sheet)
            }
            // ── Lead Detail push ──
            .navigationDestination(for: Lead.self) { lead in
                LeadDetailView(lead: lead) { id, status in
                    viewModel.updateLeadStatus(id: id, status: status)
                }
            }
            .refreshable {
                viewModel.loadLeads()
            }
        }
    }

    // MARK: - Sticky Header
    private var stickyHeader: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $viewModel.searchText)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)

            Divider().opacity(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.filters) { filter in
                        FilterChipView(
                            filter: filter,
                            count: viewModel.count(for: filter),
                            isSelected: viewModel.selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectFilter(filter)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }

            Divider().opacity(0.5)
        }
        .background(Color.surfaceSecondary)
    }

    // MARK: - List Content
    @ViewBuilder
    private var leadListContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.filteredLeads.isEmpty {
            EmptyStateView(
                filter: viewModel.selectedFilter,
                searchText: viewModel.searchText
            ) { viewModel.showAddLead = true }
        } else {
            leadList
        }
    }

    // MARK: - Lead List
    private var leadList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredLeads.enumerated()), id: \.element.id) { index, lead in
                    // NavigationLink for push navigation
                    NavigationLink(value: lead) {
                        LeadRowContent(lead: lead)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.filteredLeads.count - 1 {
                        Divider().padding(.leading, 76)
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
            .padding(.bottom, AppSpacing.xl)
        }
        .confirmationDialog("Delete Lead", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let lead = leadToDelete,
                   let idx = viewModel.filteredLeads.firstIndex(where: { $0.id == lead.id }) {
                    viewModel.deleteLead(at: IndexSet([idx]))
                }
                leadToDelete = nil
            }
            Button("Cancel", role: .cancel) { leadToDelete = nil }
        } message: {
            if let lead = leadToDelete {
                Text("Delete \(lead.name)'s lead? This cannot be undone.")
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(Color.brandBlue)
            Text("Loading leads…")
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row Content (pure visual, no button wrapper)
struct LeadRowContent: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(
                initials: lead.initials,
                color: lead.name.avatarColor,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lead.name)
                        .font(AppFont.bodyMedium())
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    StatusBadgeView(status: lead.status)
                }
                HStack(spacing: 6) {
                    Image(systemName: lead.loanType.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.textTertiary)
                    Text(lead.loanType.rawValue)
                        .font(AppFont.subhead())
                        .foregroundColor(Color.textSecondary)
                    Text("·")
                        .foregroundColor(Color.textTertiary)
                    Text(lead.formattedAmount)
                        .font(AppFont.subheadMed())
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                    Text(lead.timeAgo)
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.surfacePrimary)
        .contentShape(Rectangle())
    }
}

#Preview {
    LeadsView()
}

