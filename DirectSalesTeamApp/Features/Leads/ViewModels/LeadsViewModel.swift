import Foundation
import Combine
import SwiftUI

@MainActor
final class LeadsViewModel: ObservableObject {

    // MARK: - Published State
    @Published var leads: [Lead]           = []
    @Published var filteredLeads: [Lead]   = []
    @Published var selectedFilter: LeadFilter = .all
    @Published var searchText: String      = ""
    @Published var isLoading: Bool         = false
    @Published var errorMessage: String?   = nil
    @Published var showAddLead: Bool       = false {
        didSet {
            // Pre-fetch products when the sheet is about to open so AddLeadView
            // doesn't need to run an async task inside the sheet (which resets form state).
            if showAddLead && loanProducts.isEmpty {
                Task { await fetchLoanProducts() }
            }
        }
    }
    @Published var loanProducts: [LoanProduct] = []
    
    // MARK: - Scroll Tracking
    @Published var scrollOffset: CGFloat = 0
    @Published var contentWidth: CGFloat = 0
    @Published var viewWidth: CGFloat = 0
    
    var canScrollLeft: Bool { scrollOffset < -5 }
    var canScrollRight: Bool { viewWidth > 0 && contentWidth > viewWidth && scrollOffset > -(contentWidth - viewWidth + 5) }

    // MARK: - Filters
    let filters: [LeadFilter] = LeadFilter.leadsTabFilters

    // MARK: - Private
    private let service: LeadServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(service: LeadServiceProtocol = BackendLeadService()) {
        self.service = service
        setupBindings()
        loadLeads()
        // Pre-fetch products eagerly so they're ready when the add-lead sheet opens
        Task { await fetchLoanProducts() }
        
        // Listen for global data changes (e.g. from Applications tab)
        NotificationCenter.default.addObserver(forName: .dstDataChanged, object: nil, queue: .main) { [weak self] _ in
            self?.loadLeads()
        }
    }

    func fetchLoanProducts() async {
        do {
            let products = try await service.fetchLoanProducts()
            loanProducts = products
        } catch {
            print("DEBUG: Failed to fetch loan products: \(error.localizedDescription)")
        }
    }

    // MARK: - Bindings
    private func setupBindings() {
        // Re-filter whenever search text or selected filter changes
        Publishers.CombineLatest3($leads, $searchText, $selectedFilter)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .map { leads, search, filter in
                leads
                    .filter { lead in
                        // Leads tab: only show pre-submission statuses
                        let preSubmission: Set<LeadStatus> = [.new, .docsPending]
                        guard preSubmission.contains(lead.status) else { return false }
                        // Filter chip
                        if let required = filter.status, lead.status != required { return false }
                        // Search
                        if search.isEmpty { return true }
                        let q = search.lowercased()
                        return lead.name.lowercased().contains(q)
                            || lead.phone.contains(q)
                            || lead.loanType.rawValue.lowercased().contains(q)
                    }
                    .sorted { $0.createdAt > $1.createdAt }
            }
            .assign(to: &$filteredLeads)
    }

    // MARK: - Actions
    func loadLeads() {
        isLoading = true
        errorMessage = nil
        service.fetchLeads()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] serverLeads in
                guard let self = self else { return }
                
                // Merge logic to handle backend indexing latency:
                // Keep local leads that are NOT in the server list yet, provided they were created very recently (within 15s).
                let now = Date()
                let localOnly = self.leads.filter { local in
                    !serverLeads.contains(where: { $0.id == local.id || ($0.applicationID != nil && $0.applicationID == local.applicationID) }) &&
                    now.timeIntervalSince(local.createdAt) < 15
                }
                
                withAnimation(.easeInOut) {
                    self.leads = (serverLeads + localOnly).sorted { $0.createdAt > $1.createdAt }
                }
            }
            .store(in: &cancellables)
    }

    func selectFilter(_ filter: LeadFilter) {
        selectedFilter = filter
    }

    func addLead(_ lead: Lead, completion: ((Bool) -> Void)? = nil) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        print("DEBUG: Adding lead for \(lead.name)...")
        service.addLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completionStatus in
                if case .failure(let err) = completionStatus {
                    print("DEBUG: Failed to add lead: \(err.localizedDescription)")
                    self?.errorMessage = err.localizedDescription
                    completion?(false)
                }
            } receiveValue: { [weak self] newLead in
                guard let self = self else { return }
                print("DEBUG: Successfully added lead: \(newLead.id)")
                
                // Add to local list immediately for instant UI feedback
                let isDuplicate = self.leads.contains { $0.id == newLead.id || ($0.applicationID != nil && $0.applicationID == newLead.applicationID) }
                if !isDuplicate {
                    withAnimation {
                        self.leads.insert(newLead, at: 0)
                    }
                }
                
                // Notify other parts of the app (like Applications tab) that data changed
                NotificationCenter.default.post(name: .dstDataChanged, object: nil)
                completion?(true)
            }
            .store(in: &cancellables)
    }

    func updateLeadStatus(id: String, status: LeadStatus) {
        guard var lead = leads.first(where: { $0.id == id }) else { return }
        lead.status = status
        lead.updatedAt = Date()
        updateLead(lead)
    }

    func updateLead(_ lead: Lead) {
        service.updateLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] updatedLead in
                guard let self = self else { return }
                if let idx = self.leads.firstIndex(where: { $0.id == updatedLead.id }) {
                    self.leads[idx] = updatedLead
                }
            }
            .store(in: &cancellables)
    }

    func deleteLead(_ lead: Lead) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        // All leads are now backend applications (DRAFT or later);
        // cancellation is always allowed from the Leads tab.
        isLoading = true
        errorMessage = nil

        service.deleteLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                    // Re-sync so a cancelled lead that failed to cancel doesn't disappear locally.
                    self?.loadLeads()
                }
            } receiveValue: { [weak self] _ in
                guard let self = self else { return }
                withAnimation {
                    self.leads.removeAll { $0.id == lead.id }
                    self.filteredLeads.removeAll { $0.id == lead.id }
                }
                // Re-sync from backend to ensure cancelled leads never reappear.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadLeads()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed
    var leadCountText: String {
        let count = filteredLeads.count
        return count == 1 ? "1 lead" : "\(count) leads"
    }

    func count(for filter: LeadFilter) -> Int {
        let preSubmission: Set<LeadStatus> = [.new, .docsPending]
        let base = leads.filter { preSubmission.contains($0.status) }
        if filter.status == nil { return base.count }
        return base.filter { $0.status == filter.status }.count
    }

    var newLeadCount: Int {
        leads.filter { $0.status == .new }.count
    }

    var docsPendingLeadCount: Int {
        leads.filter { $0.status == .docsPending }.count
    }

    var totalLeadsCount: Int {
        newLeadCount + docsPendingLeadCount
    }
}
