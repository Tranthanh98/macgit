import Foundation

struct HistoryCommitSelection: Equatable {
    struct Modifiers: OptionSet, Equatable {
        let rawValue: Int

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
    }

    var selectedHashes: [String]
    var primaryHash: String?
    var anchorHash: String?

    init(
        selectedHashes: [String] = [],
        primaryHash: String? = nil,
        anchorHash: String? = nil
    ) {
        self.selectedHashes = selectedHashes
        self.primaryHash = primaryHash
        self.anchorHash = anchorHash
    }

    mutating func select(_ hash: String, modifiers: Modifiers, visibleHashes: [String]) {
        guard visibleHashes.contains(hash) else { return }

        if modifiers.contains(.shift),
           let anchorHash,
           let rangeSelection = Self.rangeSelection(
               from: anchorHash,
               to: hash,
               visibleHashes: visibleHashes
           ) {
            selectedHashes = rangeSelection
            primaryHash = hash
            return
        }

        if modifiers.contains(.command) {
            toggle(hash, visibleHashes: visibleHashes)
            return
        }

        selectedHashes = [hash]
        primaryHash = hash
        anchorHash = hash
    }

    mutating func prune(visibleHashes: [String]) {
        let visibleSet = Set(visibleHashes)
        selectedHashes = visibleHashes.filter { visibleSet.contains($0) && selectedHashes.contains($0) }

        if let primaryHash, !visibleSet.contains(primaryHash) {
            self.primaryHash = selectedHashes.last
        }
        if let anchorHash, !visibleSet.contains(anchorHash) {
            self.anchorHash = primaryHash ?? selectedHashes.last
        }
        if selectedHashes.isEmpty {
            primaryHash = nil
            anchorHash = nil
        }
    }

    func draggedHashes(startingAt hash: String, visibleHashes: [String]) -> [String] {
        let draggedSelection: [String]
        if selectedHashes.contains(hash) {
            draggedSelection = selectedHashes
        } else if visibleHashes.contains(hash) {
            draggedSelection = [hash]
        } else {
            draggedSelection = []
        }

        let draggedSet = Set(draggedSelection)
        return visibleHashes.filter { draggedSet.contains($0) }.reversed()
    }

    private mutating func toggle(_ hash: String, visibleHashes: [String]) {
        if selectedHashes.contains(hash) {
            selectedHashes.removeAll { $0 == hash }
            primaryHash = selectedHashes.last
            anchorHash = primaryHash
            return
        }

        let selectedSet = Set(selectedHashes).union([hash])
        selectedHashes = visibleHashes.filter { selectedSet.contains($0) }
        primaryHash = hash
        anchorHash = hash
    }

    private static func rangeSelection(
        from anchorHash: String,
        to hash: String,
        visibleHashes: [String]
    ) -> [String]? {
        guard let anchorIndex = visibleHashes.firstIndex(of: anchorHash),
              let targetIndex = visibleHashes.firstIndex(of: hash) else {
            return nil
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        return Array(visibleHashes[lowerBound...upperBound])
    }
}
