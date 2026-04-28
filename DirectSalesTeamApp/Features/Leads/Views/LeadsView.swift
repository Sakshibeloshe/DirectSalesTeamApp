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

                    if !viewModel.isLoading {
                        HStack {
                            Text(viewModel.leadCountText)
                                .font(AppFont.subheadMed())
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.xs)
                        .padding(.bottom, AppSpacing.xs)
                    }

                    leadListContent
                }
                .padding(.top, -8)
            }
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
            .onReceive(NotificationCenter.default.publisher(for: .dstDataChanged)) { _ in
                viewModel.loadLeads()
            }
        }
    }

    private var leadsHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Lead Pipeline", subtitle: "Capture prospects, move them forward quickly, and keep every sales touchpoint visible.")

                HStack(spacing: AppSpacing.sm) {
                    leadMetric(title: "New", value: "\(viewModel.newLeadCount)", valueColor: Color.textPrimary)
                    leadMetric(title: "Docs Pending", value: "\(viewModel.docsPendingLeadCount)", valueColor: Color.brandBlue)
                    leadMetric(title: "Total Leads", value: "\(viewModel.totalLeadsCount)", valueColor: Color.brandBlue)
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
            SearchBarView(text: $viewModel.searchText)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)

            ScrollViewReader { proxy in
                GeometryReader { outerGeo in
                    HStack(spacing: 0) {
                        if viewModel.canScrollLeft {
                            Button {
                                if let first = viewModel.filters.first {
                                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first.id, anchor: .leading) }
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.textTertiary)
                                    .padding(.leading, AppSpacing.md)
                                    .padding(.trailing, AppSpacing.xs)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(viewModel.filters) { filter in
                                    FilterChipView(
                                        filter: filter,
                                        count: viewModel.count(for: filter),
                                        isSelected: viewModel.selectedFilter == filter
                                    ) {
                                        viewModel.selectFilter(filter)
                                    }
                                    .id(filter.id)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ScrollOffsetTracker.self, value: geo.frame(in: .named("leadsScroll")).minX)
                                        .onAppear { viewModel.contentWidth = geo.size.width }
                                        .onChange(of: geo.size.width) { _ in viewModel.contentWidth = geo.size.width }
                                }
                            )
                        }
                        .coordinateSpace(name: "leadsScroll")
                        .onPreferenceChange(ScrollOffsetTracker.self) { value in viewModel.scrollOffset = value }

                        if viewModel.canScrollRight {
                            Button {
                                if let last = viewModel.filters.last {
                                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .trailing) }
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.textTertiary)
                                    .padding(.trailing, AppSpacing.md)
                                    .padding(.leading, AppSpacing.xs)
                            }
                        }
                    }
                    .onAppear { viewModel.viewWidth = outerGeo.size.width }
                    .onChange(of: outerGeo.size.width) { _ in viewModel.viewWidth = outerGeo.size.width }
                }
                .frame(height: 44)
            }
            .padding(.bottom, AppSpacing.xs)
        }
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
        } else {
            leadList
        }
    }

    // MARK: - Lead List
    private var leadList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredLeads, id: \.id) { lead in
                    NavigationLink(value: lead) {
                        LeadRowContent(lead: lead)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            leadToDelete = lead
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Lead", systemImage: "trash")
                        }
                    }

                    if lead.id != viewModel.filteredLeads.last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.borderLight.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .confirmationDialog("Delete Lead?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let lead = leadToDelete {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.deleteLead(lead)
                    }
                }
                leadToDelete = nil
            }
            Button("Cancel", role: .cancel) { leadToDelete = nil }
        } message: {
            if let lead = leadToDelete {
                Text("Are you sure you want to delete \(lead.name)'s \(lead.loanType.rawValue) lead? This action cannot be undone.")
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
        HStack(spacing: 16) {
            AvatarView(
                initials: lead.initials,
                color: lead.name.avatarColor,
                size: 44
            )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lead.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    StatusBadgeView(status: lead.status)
                        .scaleEffect(0.9)
                }
                
                HStack(spacing: 8) {
                    Label(lead.loanType.rawValue, systemImage: lead.loanType.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                    
                    Text("•")
                        .foregroundColor(Color.textTertiary)
                    
                    Text(lead.formattedAmount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.brandBlue)
                    
                    Spacer()
                    
                    Text(lead.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfacePrimary)
        .contentShape(Rectangle())
    }
}

#Preview {
    LeadsView(viewModel: LeadsViewModel())
}
