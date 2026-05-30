# Change: Add Merge Button Feature

## Why
The Merge toolbar button in `MainWindowView.swift` currently has an empty action (`{}`). Users need a way to merge another branch (local or remote) into the current branch directly from the toolbar, similar to how Pull, Push, and Branch are already implemented.

## What Changes
- Add a `MergeSheetView` SwiftUI sheet for selecting a source branch and merge options.
- Hook the Merge toolbar button and More-menu Merge item to open the new sheet.
- Add `GitStatusService.merge(...)` to execute `git merge` with optional `--no-ff` and `--squash` flags.
- Add `SyncState.performMerge(...)` to orchestrate conflict checking, loading state, success/error alerts, and refresh.
- Update `SyncState.isAnySyncing` to include an `isMerging` flag.
- Extend conflict detection to block Merge when unresolved conflicts exist.

## Impact
- **Affected specs:** `main-window`, `git-remote-sync`
- **Affected code:**
  - `macgit/Views/MainWindow/MainWindowView.swift`
  - `macgit/Views/Common/MergeSheetView.swift` (new)
  - `macgit/Services/SyncState.swift`
  - `macgit/Services/GitStatusService.swift`
