//
//  EarningsViewModel.swift
//  LoanApp
//

import Combine
import Foundation
import SwiftUI

@MainActor
class EarningsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var earnings: [Earning] = []
    @Published var stats: EarningsStats?
    @Published var commissionRates: [CommissionRate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filtering
    @Published var selectedFilter: EarningFilter = .all
    @Published var searchText = ""
    
    // Calculator
    @Published var showCalculator = false
    @Published var showCommissionRates = false
    
    enum EarningFilter: String, CaseIterable {
        case all = "All"
        case paid = "Paid"
        case pending = "Pending"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .paid: return "checkmark.circle"
            case .pending: return "clock"
            }
        }
    }
    
    // MARK: - Dependencies
    private let appService: ApplicationServiceProtocol
    
    // MARK: - Computed Properties
    var filteredEarnings: [Earning] {
        var filtered = earnings
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .paid:
            filtered = filtered.filter { $0.status == .paid }
        case .pending:
            filtered = filtered.filter { $0.status == .pending }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                $0.loanApplicationId.localizedCaseInsensitiveContains(searchText) ||
                $0.loanType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by date (most recent first)
        return filtered.sorted { $0.transactionDate > $1.transactionDate }
    }
    
    var earningsByMonth: [(month: String, earnings: [Earning])] {
        let grouped = Dictionary(grouping: filteredEarnings) { earning in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: earning.transactionDate)
        }
        
        return grouped.sorted { first, second in
            guard let firstDate = filteredEarnings.first(where: {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: $0.transactionDate) == first.key
            })?.transactionDate,
            let secondDate = filteredEarnings.first(where: {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: $0.transactionDate) == second.key
            })?.transactionDate else {
                return false
            }
            return firstDate > secondDate
        }.map {
            (month: $0.key,
             earnings: $0.value.sorted { $0.transactionDate > $1.transactionDate })
        }
    }
    
    // MARK: - Initialization
    init(appService: ApplicationServiceProtocol = BackendApplicationService()) {
        self.appService = appService
    }
    
    // MARK: - API Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use withCheckedThrowingContinuation or combine to bridge Combine -> Async/Await
            let apps = try await fetchApplicationsAsync()
            
            // 1. Filter disbursed applications
            let disbursedApps = apps.filter { $0.status == .disbursed }
            
            // 2. Map to Earnings
            let fetchedEarnings = disbursedApps.map { app in
                Earning(
                    id: app.id,
                    loanApplicationId: app.referenceNumber ?? app.id,
                    customerName: app.name,
                    loanType: mapToEarningLoanType(app.loanType),
                    loanAmount: app.loanAmount,
                    commissionRate: 0.35, // 0.35%
                    commissionAmount: app.loanAmount * 0.0035,
                    status: .paid, // Disbursed = Paid for this context
                    transactionDate: app.updatedAt,
                    expectedPayoutDate: app.updatedAt,
                    actualPayoutDate: app.updatedAt,
                    disbursementDate: app.updatedAt
                )
            }
            
            // 3. Calculate Stats
            let totalCommission = fetchedEarnings.reduce(0) { $0 + $1.commissionAmount }
            let thisMonthEarnings = fetchedEarnings.filter { 
                Calendar.current.isDate($0.transactionDate, equalTo: Date(), toGranularity: .month) 
            }.reduce(0) { $0 + $1.commissionAmount }
            
            let fetchedStats = EarningsStats(
                totalLifetimeEarnings: totalCommission,
                thisMonthEarnings: thisMonthEarnings,
                pendingPayout: 0,
                paidTransactionsCount: fetchedEarnings.count,
                pendingTransactionsCount: 0,
                averagePayoutRate: 0.35,
                totalTransactionsCount: fetchedEarnings.count
            )
            
            self.earnings = fetchedEarnings
            self.stats = fetchedStats
            self.commissionRates = []
            
        } catch {
            errorMessage = "Failed to load earnings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func fetchApplicationsAsync() async throws -> [LoanApplication] {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = appService.fetchApplications()
                .sink { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { apps in
                    continuation.resume(returning: apps)
                }
        }
    }
    
    private func mapToEarningLoanType(_ type: LoanType) -> Earning.LoanType {
        switch type {
        case .home: return .homeLoan
        case .personal: return .personalLoan
        case .business: return .businessLoan
        case .auto: return .autoLoan
        case .education: return .educationLoan
        }
    }
    
    func selectFilter(_ filter: EarningFilter) {
        selectedFilter = filter
    }
    
    func calculateCommission(for loanType: Earning.LoanType, amount: Double) -> Double {
        return amount * 0.0035
    }
    
    func getCommissionRates(for loanType: Earning.LoanType) -> [CommissionRate] {
        commissionRates
            .filter { $0.loanType == loanType }
            .sorted { $0.minAmount < $1.minAmount }
    }
    
    // MARK: - Formatting Helpers
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return "₹" + (formatter.string(from: NSNumber(value: amount)) ?? "0")
    }
    
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: date)
    }
    
    func getExpectedPayoutText(for earning: Earning) -> String {
        if let actualDate = earning.actualPayoutDate {
            return "Paid on \(formatDate(actualDate))"
        } else if let expectedDate = earning.expectedPayoutDate {
            if earning.disbursementDate != nil {
                return "Payout releases after disbursement: expected \(formatDate(expectedDate))"
            } else {
                return "Expected after disbursement"
            }
        }
        return "Pending disbursement"
    }
    
    // MARK: - 🔥 DETAIL SCREEN MAPPING (NEW)
    
    // MARK: - DETAIL SCREEN MAPPING

    func mapToDetail(_ earning: Earning) -> EarningDetail {
        return EarningDetail(
            id: earning.id,
            borrowerName: earning.customerName,
            loanType: earning.loanType.rawValue,
            loanAmount: earning.loanAmount,
            commission: earning.commissionAmount, // ✅ FIXED
            commissionRate: earning.commissionRate,
            status: mapStatus(earning.status),
            disbursementDate: earning.disbursementDate ?? earning.transactionDate,
            
            breakdown: [
                CommissionComponent(title: "Base Commission", amount: earning.commissionAmount * 0.7), // ✅ FIXED
                CommissionComponent(title: "Bonus", amount: earning.commissionAmount * 0.2),
                CommissionComponent(title: "Incentive", amount: earning.commissionAmount * 0.1)
            ],
            
            borrower: Borrower(
                name: earning.customerName,
                phone: "9876543210",
                city: "Mumbai"
            ),
            
            timeline: [
                TimelineStep(title: "Application Submitted", isCompleted: true),
                TimelineStep(title: "Approved", isCompleted: true),
                TimelineStep(title: "Disbursed", isCompleted: earning.disbursementDate != nil),
                TimelineStep(title: "Commission Generated", isCompleted: earning.status != .pending),
                TimelineStep(title: "Payout Released", isCompleted: earning.status == .paid)
            ]
        )
    }

    private func mapStatus(_ status: Earning.EarningStatus) -> EarningPaymentStatus { // ✅ FIXED
        switch status {
        case .paid: return .paid
        case .pending: return .pending
        case .processing: return .processing
        case .cancelled: return .pending // or handle separately if needed
        }
    }

}
