# History Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the history view fast on large repositories by loading the selected branch tip first, then appending older commits as the user scrolls downward.

**Architecture:** Move commit-history paging into `GitStatusService` so the view can request deterministic slices by ref, limit, and skip. `HistoryView` will own a small paging state for the current scope, keep the newest page selected at the top, and ask for the next page only when the last visible row appears. The graph layout will continue to work on the full loaded slice, so appending a page simply recomputes the layout for the current in-memory list.

**Tech Stack:** Swift 5, SwiftUI, Git CLI via `GitStatusService`, XCTest.

---

### Task 1: Add paged commit-history queries

**Files:**
- Modify: `macgit/Services/GitStatusService+Commit.swift`
- Modify: `macgitTests/HistoryPaginationTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `macgitTests/HistoryPaginationTests.swift` with a temp-repo fixture and tests that prove branch-scoped history pages return the newest commits first and that `skip` advances the page boundary:

```swift
import XCTest
@testable import macgit

final class HistoryPaginationTests: XCTestCase {
    func testCommitHistoryPageSkipsOlderCommits() async throws {
        let repoURL = try makeRepoWithLinearHistory(commitCount: 6)

        let firstPage = await GitStatusService.shared.commitHistory(
            branch: "main",
            limit: 3,
            skip: 0,
            in: repoURL
        )
        let secondPage = await GitStatusService.shared.commitHistory(
            branch: "main",
            limit: 3,
            skip: 3,
            in: repoURL
        )

        XCTAssertEqual(firstPage.map(\.message), ["commit 6", "commit 5", "commit 4"])
        XCTAssertEqual(secondPage.map(\.message), ["commit 3", "commit 2", "commit 1"])
    }

    func testBranchHistoryPageReturnsBranchTipFirst() async throws {
        let repoURL = try makeRepoWithMergedMainAndFeatureTip()

        let featurePage = await GitStatusService.shared.commitHistory(
            branch: "feature",
            limit: 2,
            skip: 0,
            in: repoURL
        )

        XCTAssertEqual(featurePage.first?.message, "feature tip")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/HistoryPaginationTests
```

Expected: fail because the paged `commitHistory(branch:limit:skip:in:)` APIs do not exist yet.

- [ ] **Step 3: Add the minimal implementation**

Add paged variants to `GitStatusService+Commit.swift` and keep the existing 500-commit helpers as wrappers:

```swift
func commitHistory(allBranches: Bool, limit: Int, skip: Int = 0, in repositoryURL: URL) async -> [Commit] {
    var arguments = ["log"]
    if allBranches { arguments.append("--all") }
    arguments.append(contentsOf: [
        "--format=%H%x00%P%x00%s%x00%an%x00%ae%x00%ad%x00%D",
        "--date=iso-strict",
        "--max-count", "\(limit)"
    ])
    if skip > 0 {
        arguments.append(contentsOf: ["--skip", "\(skip)"])
    }
    let output = (try? await runGit(arguments: arguments, in: repositoryURL)) ?? ""
    return parseCommitLog(output)
}

func commitHistory(branch: String, limit: Int, skip: Int = 0, in repositoryURL: URL) async -> [Commit] {
    var arguments = ["log", branch]
    arguments.append(contentsOf: [
        "--format=%H%x00%P%x00%s%x00%an%x00%ae%x00%ad%x00%D",
        "--date=iso-strict",
        "--max-count", "\(limit)"
    ])
    if skip > 0 {
        arguments.append(contentsOf: ["--skip", "\(skip)"])
    }
    let output = (try? await runGit(arguments: arguments, in: repositoryURL)) ?? ""
    return parseCommitLog(output)
}
```

Then keep the current methods as thin wrappers:

```swift
func commitHistory(allBranches: Bool, in repositoryURL: URL) async -> [Commit] {
    await commitHistory(allBranches: allBranches, limit: 500, skip: 0, in: repositoryURL)
}

func commitHistory(branch: String, in repositoryURL: URL) async -> [Commit] {
    await commitHistory(branch: branch, limit: 500, skip: 0, in: repositoryURL)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/HistoryPaginationTests
```

Expected: PASS.

### Task 2: Add scroll-driven loading in HistoryView

**Files:**
- Modify: `macgit/Views/History/HistoryView.swift`
- Create: `macgit/Views/History/HistoryPagingState.swift`
- Modify: `macgitTests/HistoryPaginationTests.swift`

- [ ] **Step 1: Write the failing tests for paging state**

Add a small pure-state test for the paging helper:

```swift
func testHistoryPagingStateResetsOnScopeChange() {
    var state = HistoryPagingState(pageSize: 100)
    state.markLoaded(pageCount: 100)
    state.markLoaded(pageCount: 40)

    XCTAssertEqual(state.loadedCount, 140)
    XCTAssertTrue(state.hasMore)

    state.reset()

    XCTAssertEqual(state.loadedCount, 0)
    XCTAssertTrue(state.hasMore)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/HistoryPaginationTests
```

Expected: fail until `HistoryPagingState` exists.

- [ ] **Step 3: Implement the paging helper and view changes**

Create `HistoryPagingState` as a tiny state container:

```swift
struct HistoryPagingState {
    var pageSize: Int
    private(set) var loadedCount: Int = 0
    private(set) var hasMore: Bool = true
    private(set) var isLoadingMore: Bool = false

    mutating func reset() {
        loadedCount = 0
        hasMore = true
        isLoadingMore = false
    }

    mutating func beginLoadingMore() -> Bool {
        guard hasMore, !isLoadingMore else { return false }
        isLoadingMore = true
        return true
    }

    mutating func finishLoadingMore(loaded pageCount: Int) {
        loadedCount += pageCount
        hasMore = pageCount == pageSize
        isLoadingMore = false
    }
}
```

In `HistoryView`:

- keep branch tip selection on the first page
- load the first page on scope changes
- append newer pages when the last visible row appears
- show a footer spinner while the next page is loading
- recompute `graphLayout` after each append

Use the last row's `.onAppear` to trigger:

```swift
if index == layout.nodes.count - 1 {
    Task { await loadOlderHistoryIfNeeded() }
}
```

Fetch the next slice with `skip: pager.loadedCount` and `limit: pager.pageSize`, then append the returned commits to the existing array.

- [ ] **Step 4: Run the paging tests and app build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/HistoryPaginationTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and the app builds cleanly.

### Task 3: Verify branch-tip behavior end to end

**Files:**
- Modify: `macgitTests/HistoryPaginationTests.swift`

- [ ] **Step 1: Add an end-to-end branch-tip assertion**

Add one more integration test that opens a repo where the feature branch tip is not the repository-wide newest commit, then confirms the first page for that branch still returns the branch tip first:

```swift
func testSelectedBranchStillStartsAtItsTipWhenOlderThanMain() async throws {
    let repoURL = try makeRepoWithOlderFeatureBranchTip()

    let featurePage = await GitStatusService.shared.commitHistory(
        branch: "feature",
        limit: 50,
        skip: 0,
        in: repoURL
    )

    XCTAssertEqual(featurePage.first?.message, "feature tip")
}
```

- [ ] **Step 2: Run the full history pagination suite**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/HistoryPaginationTests
```

Expected: PASS.

- [ ] **Step 3: Run the full app test suite**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: PASS, with any unrelated pre-existing failures documented if they remain.
