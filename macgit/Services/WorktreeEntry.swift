import Foundation

nonisolated struct WorktreeEntry: Identifiable, Equatable, Sendable {
    var id: URL { path }
    let path: URL
    let head: String
    let branch: String?
    let isLocked: Bool
    let dirtyCount: Int
    var label: String?

    var displayTitle: String {
        if let label, !label.isEmpty {
            return label
        }

        if let branch {
            return branch
        }

        return "detached \(head)"
    }
}
