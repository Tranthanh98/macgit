import Foundation

nonisolated enum GitCherryPickExecutionLocation: Sendable, Equatable {
    case currentWorkingCopy
    case existingWorktree(URL)
    case temporaryWorktree
}

nonisolated struct GitCherryPickWorktreeError: LocalizedError, Sendable {
    enum WorktreeKind: Sendable, Equatable {
        case existing
        case temporary
    }

    let path: URL
    let kind: WorktreeKind
    let isConflict: Bool
    let gitMessage: String
    let cleanupMessage: String?

    var errorDescription: String? {
        let worktreeDescription = kind == .existing ? "existing worktree" : "temporary worktree"

        if isConflict {
            return "Cherry-pick produced conflicts in the \(worktreeDescription) at \(path.path). Open that worktree to resolve or abort the cherry-pick manually.\n\n\(gitMessage)"
        }

        if let cleanupMessage {
            return "\(gitMessage)\n\nTemporary worktree: \(path.path)\n\nCleanup error: \(cleanupMessage)"
        }

        return "Cherry-pick failed in the \(worktreeDescription) at \(path.path).\n\n\(gitMessage)"
    }
}
