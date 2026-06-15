import SwiftUI
import Combine

@MainActor
final class SearchCoordinator: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var selectedResultID: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private let repositoryURL: URL
    
    init(repositoryURL: URL) {
        self.repositoryURL = repositoryURL
        
        $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            results = []
            selectedResultID = nil
            isLoading = false
            return
        }
        
        isLoading = true
        
        searchTask = Task { [weak self] in
            guard let self = self else { return }
            defer { self.searchTask = nil }
            let searchResults = await GitStatusService.shared.search(query: query, in: repositoryURL)
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                self.results = searchResults
                self.selectedResultID = searchResults.first?.id
                self.isLoading = false
            }
        }
    }
    
    func selectNext() {
        guard let currentID = selectedResultID,
              let currentIndex = results.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < results.count else { return }
        selectedResultID = results[currentIndex + 1].id
    }
    
    func selectPrevious() {
        guard let currentID = selectedResultID,
              let currentIndex = results.firstIndex(where: { $0.id == currentID }),
              currentIndex > 0 else { return }
        selectedResultID = results[currentIndex - 1].id
    }
    
    func selectedResult() -> SearchResult? {
        guard let selectedResultID = selectedResultID else { return nil }
        return results.first(where: { $0.id == selectedResultID })
    }
    
    func clear() {
        query = ""
        results = []
        selectedResultID = nil
        isLoading = false
        searchTask?.cancel()
    }
}
