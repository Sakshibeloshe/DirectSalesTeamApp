import SwiftUI

@MainActor
struct LeadsView: View {
    @ObservedObject var viewModel: LeadsViewModel
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 180)

                VStack(spacing: 0) {
                    // Compact summary strip
                    HStack(spacing: AppSpacing.md) {
                        summaryItem(label: "Total", value: "\(viewModel.totalLeadsCount)")
                        summaryItem(label: "New", value: "\(viewModel.newLeadCount)")
                        summaryItem(label: "Docs Pending", value: "\(viewModel.docsPendingLeadCount)")
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
                            if viewModel.isLoading && viewModel.filteredLeads.isEmpty {
                                shimmerLoadingView
                            } else if viewModel.filteredLeads.isEmpty {
                                emptyView
                            } else {
                                leadList
                                    .padding(.top, AppSpacing.sm)
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DSTScrollToTop"))) { note in
                            if let index = note.object as? Int, index == 0 {
                                withAnimation(.spring()) {
                                    proxy.scrollTo("top_anchor", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showAddLead = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddLead) {
                AddLeadView(viewModel: viewModel)
                    .presentationDetents([.height(560), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
            }
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

    private var filterChipHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(viewModel.filters) { item in
                    let count = viewModel.count(for: item)
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

    private func chipView(for item: LeadFilter) -> some View {
        let isSelected = viewModel.selectedFilter == item
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.selectFilter(item)
        } label: {
            HStack(spacing: 5) {
                Text(item.title)
                    .font(AppFont.subheadMed())

                let count = viewModel.count(for: item)
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

    private var leadList: some View {
        LazyVStack(spacing: 0) {
            Color.clear.frame(height: 1).id("top_anchor")
            
            ForEach(viewModel.filteredLeads) { lead in
                NavigationLink(value: lead) {
                    SwipeableLeadRow(
                        lead: lead,
                        onCall: {
                            if let url = URL(string: "tel://\(lead.phone)") {
                                UIApplication.shared.open(url)
                            }
                        },
                        onDelete: {
                            viewModel.deleteLead(lead)
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if lead.id != viewModel.filteredLeads.last?.id {
                    Divider().padding(.leading, 68)
                }
            }
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.borderLight.opacity(0.8), lineWidth: 1))
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    private var shimmerLoadingView: some View {
        VStack(spacing: 0) {
            ForEach(0..<6) { _ in
                HStack(spacing: 12) {
                    Circle().fill(Color.surfaceTertiary).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.surfaceTertiary).frame(width: 140, height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(Color.surfaceTertiary).frame(width: 100, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color.surfaceTertiary).frame(width: 60, height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                Divider().padding(.leading, 68)
            }
        }
        .shimmering()
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.surfaceTertiary).frame(width: 72, height: 72)
                Image(systemName: "person.2")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            VStack(spacing: AppSpacing.xs) {
                Text(viewModel.searchText.isEmpty ? "No leads yet" : "No results for \"\(viewModel.searchText)\"")
                    .font(AppFont.headline())
                    .foregroundColor(Color.textPrimary)
                Text("Add your first lead to start building your sales pipeline.")
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }
            Button {
                viewModel.showAddLead = true
            } label: {
                Text("Add Lead")
                    .font(AppFont.subheadMed())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.top, 40)
    }
}
