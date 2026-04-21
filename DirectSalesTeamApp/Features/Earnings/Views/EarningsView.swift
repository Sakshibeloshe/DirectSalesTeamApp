//
//  EarningsView.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningsView.swift
//

import SwiftUI

struct EarningsView: View {
    @StateObject private var viewModel = EarningsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.earnings.isEmpty {
                    ProgressView("Loading earnings...")
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
                            // Summary Card
                            if let stats = viewModel.stats {
                                EarningsSummaryCard(stats: stats)
                                    .padding(.top, 8)
                            }
                            
                            // Stats Row (Tappable Filters)
                            if let stats = viewModel.stats {
                                EarningsStatsRow(
                                    stats: stats,
                                    selectedFilter: viewModel.selectedFilter,
                                    onFilterTap: { filter in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.selectFilter(filter)
                                        }
                                    }
                                )
                                .padding(.top, 8)
                            }
                            
                            // Filter Buttons
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(EarningsViewModel.EarningFilter.allCases, id: \.self) { filter in
                                        FilterPill(
                                            title: filter.rawValue,
                                            icon: filter.icon,
                                            isSelected: viewModel.selectedFilter == filter
                                        )
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.selectFilter(filter)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 8)
                            
                            // Transactions List
                            if viewModel.filteredEarnings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("No transactions found")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
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
                                                EarningTransactionRow(
                                                    earning: earning,
                                                    payoutText: viewModel.getExpectedPayoutText(for: earning)
                                                )
                                            }
                                            .buttonStyle(.plain) // keeps your UI clean
                                            
                                            if earning.id != viewModel.filteredEarnings.last?.id {
                                                Divider()
                                                    .padding(.leading, 68)
                                            }
                                        }
                                    }

                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
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
                    Menu {
                        Button {
                            viewModel.showCalculator = true
                        } label: {
                            Label("Commission Calculator", systemImage: "calculator")
                        }
                        
                        Button {
                            viewModel.showCommissionRates = true
                        } label: {
                            Label("View Commission Rates", systemImage: "list.bullet.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCalculator) {
                CommissionCalculatorSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCommissionRates) {
                CommissionRateCard(rates: viewModel.commissionRates)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(isSelected ? .white : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.brandBlue : Color(.systemGray5))
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    EarningsView()
}
