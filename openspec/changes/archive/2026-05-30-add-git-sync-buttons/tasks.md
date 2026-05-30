## 1. Backend Service Extensions
- [x] 1.1 Add `fetch(in:)` method to `GitStatusService` that runs `git fetch`.
- [x] 1.2 Add `pull(in:)` method to `GitStatusService` that runs `git pull`.
- [x] 1.3 Add `aheadBehindCount(in:)` method to `GitStatusService` that returns `(ahead: Int, behind: Int)` using `git rev-list --count`.
- [x] 1.4 Add `hasConflicts(in:)` helper to `GitStatusService` that returns true if `status` contains any `.conflict` entries.

## 2. Shared Sync State
- [x] 2.1 Create `SyncState` observable object that holds:
  - `commitBadgeCount: Int`
  - `pushBadgeCount: Int`
  - `pullBadgeCount: Int`
  - `errorMessage: String?` / `showingError: Bool`
  - `conflictMessage: String?` / `showingConflict: Bool`
- [x] 2.2 Implement `refresh(repositoryURL:)` in `SyncState` that queries status and ahead/behind counts, updating badge values.
- [x] 2.3 Implement `startBackgroundSync(repositoryURL:)` that schedules a 60-second repeating task to call `refresh`.
- [x] 2.4 Implement `stopBackgroundSync()` to cancel the timer.

## 3. Toolbar UI Components
- [x] 3.1 Create `BadgeToolbarButton` view that wraps `ToolbarButtonLabel` and overlays a numeric badge (caps at "99+").
- [x] 3.2 Replace the four no-op toolbar buttons in `MainWindowView` with `BadgeToolbarButton` instances bound to `SyncState`.
- [x] 3.3 Commit button opens the existing commit sheet; after successful commit, call `syncState.refresh`.
- [x] 3.4 Push button triggers `GitStatusService.push` via `SyncState`; on error or conflict, `SyncState` presents the popup.
- [x] 3.5 Pull button triggers `GitStatusService.pull` via `SyncState`; on error or conflict, `SyncState` presents the popup.
- [x] 3.6 Fetch button triggers `GitStatusService.fetch` via `SyncState`; on error, `SyncState` presents the popup; on success, immediately refresh badge counts.

## 4. Error and Conflict Popups
- [x] 4.1 Attach a `.alert("Error", isPresented:)` to `MainWindowView` bound to `SyncState.showingError`.
- [x] 4.2 Attach a `.alert("Conflict", isPresented:)` to `MainWindowView` bound to `SyncState.showingConflict`.
- [x] 4.3 Before Push, Pull, and Commit actions, check `hasConflicts`. If true, set `conflictMessage` and `showingConflict = true`, then abort the Git command.
- [x] 4.4 If Pull fails and stderr contains conflict indicators, set `conflictMessage` and `showingConflict = true`.

## 5. Integration & Validation
- [x] 5.1 Instantiate `SyncState` in `MainWindowView` (or pass from `AppState`) and start background sync when a repository is opened.
- [x] 5.2 Stop background sync when the window closes or repository changes.
- [x] 5.3 Build the project with `xcodebuild` and verify no compilation errors.
- [x] 5.4 Manual test: verify badges update after staging files, committing, pushing, pulling, and fetching.
