## 1. Backend / Data Layer
- [x] 1.1 Create `GitDiffService.swift` to parse `git diff --no-color` output into `DiffHunk`/`DiffLine` models
- [x] 1.2 Add `GitStatusService.diff(for file: StatusFile, in: URL) async throws -> [DiffHunk]`

## 2. UI Layer
- [x] 2.1 Create `DiffView.swift` — render diff hunks with line numbers and color-coded lines
- [x] 2.2 Redesign `FileStatusView.swift`:
  - Two-panel `HSplitView` layout (left file list, right diff)
  - Left: List with Staged and Changed sections
  - Each row: checkbox + file name + path
  - Right: `DiffView` for selected file
- [x] 2.3 Remove `FileStatusRow.swift` (replaced by inline implementation)
- [x] 2.4 Update `MainWindowView.swift` to remove `showingCommitSheet` binding from `FileStatusView`

## 3. Integration & Polish
- [x] 3.1 Handle file selection state (track selected file, refresh diff on change)
- [x] 3.2 Ensure diff updates after stage/unstage/commit actions
- [x] 3.3 Handle binary files or files with no diff gracefully

## 4. Validation
- [x] 4.1 Build the Xcode project successfully
- [x] 4.2 Test stage/unstage via checkboxes and verify diff updates
