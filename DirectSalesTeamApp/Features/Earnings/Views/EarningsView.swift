//
//  EarningsView.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningsView.swift
//

import SwiftUI
import Charts

struct EarningsView: View {
    @StateObject private var viewModel = EarningsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)
                
                if viewModel.isLoading && viewModel.earnings.isEmpty {
                    DSTSkeletonList()
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadData()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Hero/Stats Card
                            if let stats = viewModel.stats {
                                DSTSurfaceCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("THIS MONTH")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color.textSecondary)
                                                .tracking(1.2)
                                            
                                            Text(stats.formattedMonthEarnings)
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundColor(Color.textPrimary)
                                        }
                                        
                                        if #available(iOS 16.0, *) {
                                            Chart {
                                                ForEach(sampleData) { data in
                                                    LineMark(
                                                        x: .value("Month", data.month),
                                                        y: .value("Earnings", data.value)
                                                    )
                                                    .interpolationMethod(.catmullRom)
                                                    .foregroundStyle(Color.brandBlue)
                                                    
                                                    AreaMark(
                                                        x: .value("Month", data.month),
                                                        y: .value("Earnings", data.value)
                                                    )
                                                    .interpolationMethod(.catmullRom)
                                                    .foregroundStyle(
                                                        LinearGradient(
                                                            colors: [Color.brandBlue.opacity(0.15), Color.brandBlue.opacity(0.0)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                }
                                            }
                                            .chartXAxis(.hidden)
                                            .chartYAxis(.hidden)
                                            .frame(height: 50)
                                        }
                                        
                                        HStack(spacing: 32) {
                                            summaryDetail(label: "LIFETIME", value: stats.formattedLifetimeEarnings)
                                            summaryDetail(label: "PENDING", value: stats.formattedPendingPayout, isHighlight: true)
                                            Spacer()
                                        }
                                        .padding(.top, 8)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // -- Start Filter Row --
                            FilterRowDynamic(viewModel: viewModel)
                                .padding(.top, 8)
                            // -- End Filter Row --
                            
                            // Transactions List
                            if viewModel.filteredEarnings.isEmpty {
                                DSTSurfaceCard {
                                    VStack(spacing: 12) {
                                        Image(systemName: "tray.fill")
                                            .font(.system(size: 42))
                                            .foregroundColor(.brandBlue)
                                        Text("No transactions found")
                                            .font(AppFont.bodyMedium())
                                            .foregroundColor(Color.textPrimary)
                                        Text("New commissions and payouts will appear here.")
                                            .font(AppFont.subhead())
                                            .foregroundColor(Color.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                }
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.filteredEarnings) { earning in
                                        VStack(spacing: 0) {
                                            
                                            NavigationLink {
                                                EarningDetailView(
                                                    vm: EarningDetailViewModel(
                                                        earning: viewModel.mapToDetail(earning)
                                                    )
                                                )
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    EarningTransactionRow(
                                                        earning: earning,
                                                        payoutText: viewModel.getExpectedPayoutText(for: earning)
                                                    )
                                                    
                                                    if earning.status == .pending && !viewModel.getExpectedPayoutText(for: earning).isEmpty {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "clock")
                                                                .font(.system(size: 10))
                                                            Text(viewModel.getExpectedPayoutText(for: earning).replacingOccurrences(of: "Payout releases after disbursement: ", with: ""))
                                                                .font(.system(size: 11, weight: .medium))
                                                        }
                                                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.12))
                                                        .clipShape(Capsule())
                                                        .padding(.leading, 68)
                                                        .padding(.bottom, 8)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if earning.id != viewModel.filteredEarnings.last?.id {
                                                Divider()
                                                    .padding(.leading, 68)
                                            }
                                        }
                                    }
                                }
                                .background(Color.surfacePrimary)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                        .stroke(Color.borderLight, lineWidth: 1)
                                )
                                .cardShadow()
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationTitle("Earnings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { } label: { Image(systemName: "square.and.arrow.down").font(.system(size: 18)) }
                        Button { viewModel.showCalculator = true } label: { Image(systemName: "plus.forwardslash.minus").font(.system(size: 18)) }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCalculator) { CommissionCalculatorSheet(viewModel: viewModel) }
            .sheet(isPresented: $viewModel.showCommissionRates) { CommissionRateCard(rates: viewModel.commissionRates) }
        }
        .task { await viewModel.loadData() }
    }

    private func summaryDetail(label: String, value: String, isHighlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isHighlight ? Color.statusPending : Color.textPrimary)
        }
    }
    
    private var sampleData: [ChartData] {
        [
            ChartData(month: "Jan", value: 12000),
            ChartData(month: "Feb", value: 18000),
            ChartData(month: "Mar", value: 15000),
            ChartData(month: "Apr", value: 22000),
            ChartData(month: "May", value: 19000),
            ChartData(month: "Jun", value: 26550)
        ]
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let month: String
    let value: Double
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(AppFont.subheadMed())
            .foregroundColor(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.mainBlue, Color.secondaryBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(Color.surfacePrimary)
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.borderLight, lineWidth: 1)
            )
    }
}

struct ScrollOffsetTracker: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next != 0 { value = next }
    }
}

struct FilterRowDynamic: View {
    @ObservedObject var viewModel: EarningsViewModel
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    
    var showLeftChevron: Bool { offset < -5 }
    var showRightChevron: Bool { viewWidth > 0 && contentWidth > viewWidth && offset > -(contentWidth - viewWidth + 5) }
    
    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeo in
                HStack(spacing: 0) {
                    if showLeftChevron {
                        Button {
                            if let first = EarningsViewModel.EarningFilter.allCases.first {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first, anchor: .leading) }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.trailing, 8)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(EarningsViewModel.EarningFilter.allCases, id: \.self) { filter in
                                let title: String = {
                                    switch filter {
                                    case .all: return "All"
                                    case .paid: return "Paid \(viewModel.stats?.paidTransactionsCount ?? 0)"
                                    case .pending: return "Pending \(viewModel.stats?.pendingTransactionsCount ?? 0)"
                                    }
                                }()
                                
                                Button {
                                    viewModel.selectFilter(filter)
                                } label: {
                                    FilterPill(title: title, isSelected: viewModel.selectedFilter == filter)
                                }
                                .buttonStyle(.plain)
                                .id(filter)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetTracker.self, value: geo.frame(in: .named("earningsScroll")).minX)
                                    .onAppear { contentWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { _ in contentWidth = geo.size.width }
                            }
                        )
                    }
                    .coordinateSpace(name: "earningsScroll")
                    .onPreferenceChange(ScrollOffsetTracker.self) { value in offset = value }
                    
                    if showRightChevron {
                        Button {
                            if let last = EarningsViewModel.EarningFilter.allCases.last {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .trailing) }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .onAppear { viewWidth = outerGeo.size.width }
                .onChange(of: outerGeo.size.width) { _ in viewWidth = outerGeo.size.width }
            }
            .frame(height: 36)
        }
    }
}

#Preview {
    EarningsView()
}
