import Foundation
import Combine

@MainActor
final class LeadsViewModel: ObservableObject {

    // MARK: - Published State
    @Published var leads: [Lead]           = []
    @Published var filteredLeads: [Lead]   = []
    @Published var selectedFilter: LeadFilter = .all
    @Published var searchText: String      = ""
    @Published var isLoading: Bool         = false
    @Published var errorMessage: String?   = nil
    @Published var showAddLead: Bool       = false
    
    // MARK: - Scroll Tracking
    @Published var scrollOffset: CGFloat = 0
    @Published var contentWidth: CGFloat = 0
    @Published var viewWidth: CGFloat = 0
    
    var canScrollLeft: Bool { scrollOffset < -5 }
    var canScrollRight: Bool { viewWidth > 0 && contentWidth > viewWidth && scrollOffset > -(contentWidth - viewWidth + 5) }

    // MARK: - Filters
    let filters: [LeadFilter] = LeadFilter.allFilters

    // MARK: - Private
    private let service: LeadServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(service: LeadServiceProtocol = MockLeadService.shared) {
        self.service = service
        setupBindings()
        loadLeads()
    }

    // MARK: - Bindings
    private func setupBindings() {
        // Re-filter whenever search text or selected filter changes
        Publishers.CombineLatest3($leads, $searchText, $selectedFilter)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .map { leads, search, filter in
                leads
                    .filter { lead in
                        // Status filter
                        guard filter.status == nil || lead.status == filter.status else { return false }
                        // Search filter
                        guard !search.isEmpty else { return true }
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
            } receiveValue: { [weak self] leads in
                self?.leads = leads
            }
            .store(in: &cancellables)
    }

    func selectFilter(_ filter: LeadFilter) {
        selectedFilter = filter
    }

    func addLead(_ lead: Lead) {
        service.addLead(lead)
            .receive(on: RunLoop.main)
            .sink { _ in } receiveValue: { [weak self] newLead in
                self?.leads.insert(newLead, at: 0)
            }
            .store(in: &cancellables)
    }

    func updateLeadStatus(id: UUID, status: LeadStatus) {
        guard let idx = leads.firstIndex(where: { $0.id == id }) else { return }
        leads[idx].status = status
        leads[idx].updatedAt = Date()
    }

    func deleteLead(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredLeads[$0] }
        toDelete.forEach { lead in
            service.deleteLead(id: lead.id)
                .receive(on: RunLoop.main)
                .sink { _ in } receiveValue: { [weak self] _ in
                    self?.leads.removeAll { $0.id == lead.id }
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Computed
    var leadCountText: String {
        let count = filteredLeads.count
        return count == 1 ? "1 lead" : "\(count) leads"
    }

    func count(for filter: LeadFilter) -> Int {
        if filter.status == nil { return leads.count }
        return leads.filter { $0.status == filter.status }.count
    }
}
