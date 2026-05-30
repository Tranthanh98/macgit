## 1. Implementation

- [x] 1.1 Add `createBranch(name:checkout:commit:)` and `deleteBranch(name:force:)` helpers to `GitStatusService.swift`
- [x] 1.2 Add `deleteRemoteBranch(remote:name:)` helper to `GitStatusService.swift`
- [x] 1.3 Add `localBranches` and `remoteBranches` combined fetch helper for delete list
- [x] 1.4 Create `BranchSheetView.swift` with segmented Create / Delete tabs matching SourceTree layout
- [x] 1.5 Implement **Create Branch** tab:
  - [x] 1.5.1 Show current branch label
  - [x] 1.5.2 Free-text input with live sanitization preview (`this is test branch` → `this-is-test-branch`)
  - [x] 1.5.3 Commit source picker (Working copy parent / Specified commit)
  - [x] 1.5.4 Commit picker UI for "Specified commit"
  - [x] 1.5.5 "Checkout new branch" checkbox
  - [x] 1.5.6 Create Branch button wired to service
- [x] 1.6 Implement **Delete Branches** tab:
  - [x] 1.6.1 Fetch and display local + remote branches in selectable table
  - [x] 1.6.2 Show branch type column (Local / Remote)
  - [x] 1.6.3 "Force delete regardless of merge status" checkbox
  - [x] 1.6.4 Delete Branches button with confirmation alert
- [x] 1.7 Wire `MainWindowView` toolbar Branch button and More-menu Branch item to present `BranchSheetView`
- [x] 1.8 Validate build with `xcodebuild`
