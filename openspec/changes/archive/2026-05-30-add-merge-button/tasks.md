## 1. Implementation
- [x] 1.1 Create `MergeSheetView.swift` with source branch picker, target branch display, and merge options (`--no-ff`, `--squash`, commit message)
- [x] 1.2 Add `GitStatusService.MergeOptions` struct and `merge(...)` method
- [x] 1.3 Add `SyncState.isMerging` and update `isAnySyncing`
- [x] 1.4 Add `SyncState.performMerge(...)` with conflict pre-check, success/error alerts, and refresh
- [x] 1.5 Wire `showingMergeSheet` into `MainWindowView` toolbar and `.sheet(...)` modifier
- [x] 1.6 Update conflict detection scope in `SyncState` to cover Merge operations
- [x] 1.7 Validate UI behavior at window widths >1000px and ≤1000px (More menu)

## 2. Testing
- [x] 2.1 Fast-forward merge completes without error and refreshes status
- [x] 2.2 Merge with `--no-ff` creates a merge commit
- [x] 2.3 Merge with `--squash` stages squashed changes
- [x] 2.4 Merge with unresolved existing conflicts shows conflict alert and blocks command
- [x] 2.5 Merge resulting in conflicts shows conflict alert and refreshes File status
- [x] 2.6 Merge button disabled while any sync operation is in progress
