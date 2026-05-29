## 1. Backend / Data Layer
- [x] 1.1 Create `GitStatusService.swift` with a `GitStatus` struct that parses `git status --porcelain -z` or `git status --porcelain` output into `[StatusFile]`
- [x] 1.2 Define `StatusFile` model with fields: `path`, `status` (enum: modified, staged, untracked, deleted, renamed), `displayName`
- [x] 1.3 Implement `GitStatusService.status(for: URL) async throws -> GitStatus`
- [x] 1.4 Implement `GitStatusService.stage(file: StatusFile, in: URL) async throws -> Void`
- [x] 1.5 Implement `GitStatusService.unstage(file: StatusFile, in: URL) async throws -> Void`
- [x] 1.6 Implement `GitStatusService.discard(file: StatusFile, in: URL) async throws -> Void`
- [x] 1.7 Implement `GitStatusService.commit(message: String, in: URL) async throws -> Void`

## 2. UI Layer
- [x] 2.1 Create `FileStatusRow.swift` — reusable SwiftUI row with icon, filename, path, and context-menu actions
- [x] 2.2 Replace placeholder `FileStatusView` with real implementation:
  - List with three sections (Staged, Unstaged, Untracked)
  - Each section shows `FileStatusRow` items
  - Pull-to-refresh or auto-refresh on view appear
- [x] 2.3 Add "Commit" sheet view (`CommitSheetView.swift`) with message text field and commit/cancel buttons
- [x] 2.4 Wire the Commit toolbar button in `MainWindowView` to present the commit sheet when File status is selected
- [x] 2.5 Add confirmation alert for discard action

## 3. Integration & Polish
- [x] 3.1 Hook `FileStatusView` into `MainWindowView` so `repositoryURL` is passed down correctly
- [x] 3.2 Ensure view refreshes after every stage/unstage/discard/commit action
- [x] 3.3 Handle Git command errors gracefully (show native alert with error message)

## 4. Validation
- [x] 4.1 Build the Xcode project successfully (`xcodebuild` or manual build)
- [x] 4.2 Test opening a real repository and verifying:
  - modified files appear in Unstaged
  - `git add` moves them to Staged
  - unstage moves them back
  - discard removes them with confirmation
  - commit clears the Staged section
