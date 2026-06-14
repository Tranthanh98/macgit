# Stashes Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-class Stashes section to the sidebar, let users inspect each stash as a file-by-file diff, and support apply/delete actions with confirmation.

**Architecture:** Keep stash data separate from branch/tag/remote tree logic. Model each stash as a flat row with a stable ref like `stash@{0}`, load its files and diffs through `GitStatusService`, and render the selected stash in a dedicated detail view that reuses the existing `CommitFileListView` and `DiffView` patterns.

**Tech Stack:** SwiftUI, `GitStatusService`, `CommitFileListView`, `DiffView`, `xcodebuild`, XCTest.

---

### Task 1: Add stash model and Git service operations

**Files:**
- Create: `macgit/Services/StashEntry.swift`
- Modify: `macgit/Services/GitStatusService+MergeStash.swift`
- Modify: `macgitTests/StashServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

Create a new test file with a temp-repo helper and tests that prove stash listing is parsed into displayable entries and that apply/delete commands work against a real stash:

```swift
func testListStashesParsesRefBranchAndDescription() async throws {
    let repoURL = try makeTempRepoWithOneStash(message: "test stash")
    let stashes = await GitStatusService.shared.stashes(in: repoURL)

    XCTAssertEqual(stashes.count, 1)
    XCTAssertEqual(stashes[0].ref, "stash@{0}")
    XCTAssertEqual(stashes[0].branchName, "main")
    XCTAssertEqual(stashes[0].description, "test stash")
    XCTAssertEqual(stashes[0].displayTitle, "On main : test stash")
}

func testApplyStashWithDeleteRemovesTheStash() async throws {
    let repoURL = try makeTempRepoWithOneStash(message: "delete me")
    try await GitStatusService.shared.applyStash(ref: "stash@{0}", dropAfterApplying: true, in: repoURL)

    let stashes = await GitStatusService.shared.stashes(in: repoURL)
    XCTAssertTrue(stashes.isEmpty)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/StashServiceTests
```

Expected: the build fails because `StashEntry` and the stash service methods do not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Add `StashEntry` and the Git helpers needed by the UI:

```swift
struct StashEntry: Identifiable, Hashable {
    let id = UUID()
    let ref: String
    let branchName: String
    let description: String

    var displayTitle: String {
        "On \(branchName) : \(description)"
    }
}
```

Implement stash listing by parsing `git stash list --format=%gd%x1f%gs`, extracting:

- `ref` from `%gd`
- `branchName` from the leading `On ...:` portion of `%gs`
- `description` from the remainder of `%gs`

Add `applyStash(ref:dropAfterApplying:in:)` and `dropStash(ref:in:)` to `GitStatusService` using:

- `git stash apply <ref>`
- `git stash pop <ref>` when `dropAfterApplying` is `true`
- `git stash drop <ref>` for delete

Keep the existing `changedFiles(in:commit:in:)` and `diff(for:file:in:commit:in:)` helpers reusable for stash refs so the stash detail view can reuse them without new diff plumbing.

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/StashServiceTests
```

Expected: green tests for stash listing and stash actions.

### Task 2: Add the sidebar Stashes section

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`
- Modify: `macgit/Services/SidebarSettingsStore.swift`

- [ ] **Step 1: Write the failing implementation expectations**

Extend the sidebar selection and section state so stashes behave like a first-class sidebar destination:

```swift
enum SidebarSelection: Hashable {
    case item(SidebarItem)
    case branch(String)
    case tag(String)
    case remoteBranch(String)
    case stash(String)
}

struct SidebarSectionState: Codable {
    var branchesExpanded: Bool = true
    var tagsExpanded: Bool = true
    var remotesExpanded: Bool = true
    var stashesExpanded: Bool = true
}
```

The sidebar should:

- show a real `STASHES` header
- load stashes with `GitStatusService.shared.stashes(in:)`
- render each row as `On {branch name} : {stash description}`
- select a stash on click
- open the apply confirmation on double click
- show a context menu with `Apply stash` and `Delete stash`

- [ ] **Step 2: Run the app build to confirm the missing cases**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: compile errors for the new stash selection/state until the sidebar is updated.

- [ ] **Step 3: Implement the sidebar changes**

Update `SidebarView` to:

- store `stashEntries: [StashEntry]`
- load them on `.task` and `.repositoryDidChange`
- add a `stashRowView(for:)` using the same row spacing and icon treatment as the branch rows
- toggle `sectionStates.stashesExpanded` through `SidebarSettingsStore`
- call new closures like `onRequestApplyStash` and `onRequestDeleteStash` from the row context menu and double-click handler

Keep the stashes list flat. Stashes are not folders, so they only need section-level collapse and a single row per stash.

- [ ] **Step 4: Run the build again**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: the sidebar compiles and the new `STASHES` section shows actual stash rows.

### Task 3: Add the stash detail view and confirmation sheets

**Files:**
- Create: `macgit/Views/Stashes/StashView.swift`
- Create: `macgit/Views/Common/StashActionConfirmationSheet.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`
- Modify: `macgit/Views/MainWindow/SidebarView.swift`

- [ ] **Step 1: Write the failing UI wiring**

Add a dedicated detail branch for stash selection in `MainWindowView`:

```swift
case .stash(let ref):
    StashView(repositoryURL: repositoryURL, stashRef: ref)
```

Add state for the pending stash action:

```swift
@State private var pendingStashRef: String?
@State private var pendingStashAction: StashAction?
@State private var deleteAfterApplyingStash = false
```

The confirmation sheet should support both actions:

```swift
enum StashAction {
    case apply
    case delete
}
```

`Apply stash` must show a checkbox labeled `Delete after applying`. `Delete stash` should be a destructive confirmation without that checkbox.

- [ ] **Step 2: Run the build to verify the new view types are missing**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: compile errors for `StashView` and the confirmation sheet until they are created.

- [ ] **Step 3: Implement the stash detail panel**

Create `StashView` as a two-pane inspector that mirrors the history view pattern:

- left pane: `CommitFileListView` backed by `GitStatusService.shared.changedFiles(in: stashRef, in: repositoryURL)`
- right pane: a header with the selected file name and a `DiffView` loaded from `GitStatusService.shared.diff(for: file.path, in: stashRef, in: repositoryURL)`

This view should:

- select the first file automatically after load
- clear the diff when nothing is selected
- show an empty state when the stash has no file changes
- reuse the existing `DiffView` component without changing its behavior

Implement the confirmation sheet so `MainWindowView` can present it from both the sidebar context menu and the double-click handler, then call:

- `GitStatusService.shared.applyStash(ref:dropAfterApplying:in:)`
- `GitStatusService.shared.dropStash(ref:in:)`

After either action succeeds, refresh `SyncState`, post `.repositoryDidChange`, and clear the pending stash state.

- [ ] **Step 4: Run the build again**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: the app builds and selecting a stash shows its file diffs in the main panel.

### Task 4: Verify the full stash workflow

**Files:**
- Modify as needed from Tasks 1-3

- [ ] **Step 1: Run the targeted stash tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/StashServiceTests
```

Expected: stash list parsing, apply, and delete tests pass.

- [ ] **Step 2: Run the full test suite**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: the existing branch/history/sidebar tests still pass with the new stash work in place.

- [ ] **Step 3: Do one manual UI pass**

Launch the app and verify:

- the `STASHES` section expands and collapses like the other sidebar sections
- clicking a stash opens its diff in the main panel
- right click shows `Apply stash` and `Delete stash`
- double click opens the apply confirmation modal
- `Delete after applying` changes the apply flow as expected

