import SwiftUI

@MainActor
struct LeadsView: View {
    @ObservedObject var viewModel: LeadsViewModel
    @State private var navPath = NavigationPath()
    @State private var showDeleteConfirm = false
    @State private var leadToDelete: Lead? = nil

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                VStack(spacing: 0) {
                    leadsHero
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    stickyHeader

                    leadListContent
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
            .navigationTitle("Leads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showAddLead = true } label: {
                        Text("Add Lead")
                            .font(AppFont.subheadMed())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandBlue)
                    .buttonBorderShape(.capsule)
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
                LeadDetailView(
                    lead: lead,
                    onStatusUpdate: { id, status in
                        viewModel.updateLeadStatus(id: id, status: status)
                    },
                    onLeadSave: { updatedLead in
                        viewModel.updateLead(updatedLead)
                    }
                )
            }
            .refreshable {
                viewModel.loadLeads()
            }
        }
    }

    private var leadsHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Lead Pipeline", subtitle: "Capture prospects, move them forward quickly, and keep every sales touchpoint visible.")

                HStack(spacing: AppSpacing.sm) {
                    leadMetric(title: "Total Leads", value: "\(viewModel.leads.count)", valueColor: Color.textPrimary)
                    leadMetric(title: "Submitted", value: "\(viewModel.leads.filter { $0.status == .submitted }.count)", valueColor: Color.brandBlue)
                    leadMetric(title: "Approved", value: "\(viewModel.leads.filter { $0.status == .approved }.count)", valueColor: Color.statusApproved)
                }
            }
        }
    }

    private func leadMetric(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.title2())
                .foregroundColor(valueColor)
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
                    ForEach(viewModel.filters.filter { $0.title != "All" }) { filter in
                        Button {
                            viewModel.selectFilter(filter)
                        } label: {
                            Label {
                                Text(filter.title)
                            } icon: {
                                if viewModel.selectedFilter == filter {
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
    private var leadListContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.filteredLeads.isEmpty {
            EmptyStateView(
                filter: viewModel.selectedFilter,
                searchText: viewModel.searchText
            ) { viewModel.showAddLead = true }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        } else {
            leadList
        }
    }

    // MARK: - Lead List
    private var leadList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 1).id("top_anchor")
                    
                    ForEach(viewModel.filteredLeads, id: \.id) { lead in
                        // NavigationLink for push navigation
                        NavigationLink(value: lead) {
                            LeadRowContent(lead: lead)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                leadToDelete = lead
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Lead", systemImage: "trash")
                            }
                        }

                        if lead.id != viewModel.filteredLeads.last?.id {
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
                .cardShadow()
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DSTScrollToTop"))) { note in
                if let index = note.object as? Int, index == 0 {
                    withAnimation(.spring()) {
                        proxy.scrollTo("top_anchor", anchor: .top)
                    }
                }
            }
        }
        .confirmationDialog("Delete Lead", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let lead = leadToDelete {
                    viewModel.deleteLead(lead)
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
        DSTSkeletonList()
            .padding(.horizontal, AppSpacing.md)
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
