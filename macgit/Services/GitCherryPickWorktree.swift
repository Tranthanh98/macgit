//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
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
