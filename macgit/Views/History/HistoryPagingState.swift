import Foundation

struct HistoryPagingState {
    let pageSize: Int
    private(set) var loadedCount: Int = 0
    private(set) var hasMore: Bool = true
    private(set) var isLoadingMore: Bool = false

    mutating func reset() {
        loadedCount = 0
        hasMore = true
        isLoadingMore = false
    }

    mutating func beginLoadingMore() -> Bool {
        guard hasMore, !isLoadingMore else { return false }
        isLoadingMore = true
        return true
    }

    mutating func finishLoadingMore(loaded pageCount: Int) {
        loadedCount += pageCount
        hasMore = pageCount == pageSize
        isLoadingMore = false
    }

    mutating func cancelLoadingMore() {
        isLoadingMore = false
    }
}
