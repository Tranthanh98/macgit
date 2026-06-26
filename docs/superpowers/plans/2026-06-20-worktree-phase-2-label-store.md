# Worktree Phase 2: Label Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users assign, edit, clear, persist, and see labels for Git worktrees in the sidebar, backed by a shared sidecar JSON file under the repository's common `.git/macgit/` directory.

**Architecture:** Add a focused `WorktreeLabelStore` that owns all sidecar JSON reads and writes, keyed by normalized absolute worktree path. Extend `GitStatusService+Worktree` with common-git-directory lookup, label merge, and label mutation helpers so labels work from both the main repository window and linked worktree windows. Update `SidebarView` to load labeled worktrees and expose Set/Edit/Clear Label actions from the worktree context menu.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, existing `GitStatusService`, `git rev-parse --path-format=absolute --git-common-dir`, sidecar JSON at `.git/macgit/worktree-labels.json`.

**Roadmap:** [docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md](2026-06-20-worktree-management-roadmap.md)
**Design spec:** [docs/superpowers/specs/2026-06-20-worktree-management-design.md](../specs/2026-06-20-worktree-management-design.md)

---

## Prerequisite

Phase 1 must already be merged. The codebase should contain:

- `macgit/Services/WorktreeEntry.swift`
- `macgit/Services/GitStatusService+Worktree.swift`
- `macgit/Views/MainWindow/SidebarView.swift` with a `WORKTREES` section
- `macgitTests/WorktreeServiceTests.swift`

## Scope

This phase supports:

- Persisting labels in `worktree-labels.json`.
- Reading missing or corrupt label files as empty label state.
- Setting, editing, clearing, removing, moving, and pruning labels by worktree path.
- Merging labels into `WorktreeEntry.label`.
- Displaying labels through the existing `WorktreeEntry.displayTitle`.
- Sidebar context menu actions: `Set Label...`, `Edit Label...`, and `Clear Label`.

This phase does not support creating, removing, moving, locking, pruning, or switching worktrees. Phase 3 and Phase 4 will call the store helpers added here.

## File Structure

- Create `macgit/Services/WorktreeLabelStore.swift`: sidecar JSON persistence for path-to-label state.
- Modify `macgit/Services/GitStatusService+Worktree.swift`: add common git directory lookup, labeled list helper, and label mutation helpers.
- Modify `macgit/Views/MainWindow/SidebarView.swift`: load labeled entries and add the Set/Edit/Clear Label sheet.
- Create `macgitTests/WorktreeLabelStoreTests.swift`: pure file-backed sidecar tests.
- Modify `macgitTests/WorktreeServiceTests.swift`: integration tests for service label merging and orphan pruning.
- Modify `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md`: keep Phase 2 linked as pending until implementation and tests pass.

## Task 1: Add Failing WorktreeLabelStore Tests

**Files:**
- Create: `macgitTests/WorktreeLabelStoreTests.swift`

- [x] **Step 1: Create pure store tests**

Create `macgitTests/WorktreeLabelStoreTests.swift`:

```swift
import XCTest
@testable import macgit

final class WorktreeLabelStoreTests: XCTestCase {
    func testMissingLabelFileReadsAsEmptyDictionary() throws {
        let gitDirectory = try makeTempGitDirectory()
        let store = WorktreeLabelStore()

        XCTAssertEqual(store.labels(in: gitDirectory), [:])
    }

    func testCorruptLabelFileReadsAsEmptyDictionary() throws {
        let gitDirectory = try makeTempGitDirectory()
        let labelsURL = labelFileURL(in: gitDirectory)
        try FileManager.default.createDirectory(
            at: labelsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{not-json".utf8).write(to: labelsURL)

        let store = WorktreeLabelStore()

        XCTAssertEqual(store.labels(in: gitDirectory), [:])
    }

    func testSetLabelTrimsAndPersistsByNormalizedPath() throws {
        let gitDirectory = try makeTempGitDirectory()
        let worktreePath = URL(fileURLWithPath: "/tmp/macgit-label-worktree")
        let store = WorktreeLabelStore()

        try store.setLabel("  Agent task  ", for: worktreePath, in: gitDirectory)

        XCTAssertEqual(
            store.labels(in: gitDirectory)[WorktreeLabelStore.key(for: worktreePath)],
            "Agent task"
        )
        XCTAssertEqual(store.label(for: worktreePath, in: gitDirectory), "Agent task")
    }

    func testBlankLabelRemovesExistingLabel() throws {
        let gitDirectory = try makeTempGitDirectory()
        let worktreePath = URL(fileURLWithPath: "/tmp/macgit-label-worktree")
        let store = WorktreeLabelStore()

        try store.setLabel("Review UI", for: worktreePath, in: gitDirectory)
        try store.setLabel("   ", for: worktreePath, in: gitDirectory)

        XCTAssertNil(store.label(for: worktreePath, in: gitDirectory))
        XCTAssertEqual(store.labels(in: gitDirectory), [:])
    }

    func testRemoveLabelIsIdempotent() throws {
        let gitDirectory = try makeTempGitDirectory()
        let worktreePath = URL(fileURLWithPath: "/tmp/macgit-label-worktree")
        let store = WorktreeLabelStore()

        try store.removeLabel(for: worktreePath, in: gitDirectory)
        try store.setLabel("Review UI", for: worktreePath, in: gitDirectory)
        try store.removeLabel(for: worktreePath, in: gitDirectory)
        try store.removeLabel(for: worktreePath, in: gitDirectory)

        XCTAssertEqual(store.labels(in: gitDirectory), [:])
    }

    func testMoveLabelTransfersLabelToNewPath() throws {
        let gitDirectory = try makeTempGitDirectory()
        let oldPath = URL(fileURLWithPath: "/tmp/macgit-old-worktree")
        let newPath = URL(fileURLWithPath: "/tmp/macgit-new-worktree")
        let store = WorktreeLabelStore()

        try store.setLabel("Review UI", for: oldPath, in: gitDirectory)
        try store.moveLabel(from: oldPath, to: newPath, in: gitDirectory)

        XCTAssertNil(store.label(for: oldPath, in: gitDirectory))
        XCTAssertEqual(store.label(for: newPath, in: gitDirectory), "Review UI")
    }

    func testPruneRemovesLabelsForPathsNotInValidSet() throws {
        let gitDirectory = try makeTempGitDirectory()
        let keptPath = URL(fileURLWithPath: "/tmp/macgit-kept-worktree")
        let orphanPath = URL(fileURLWithPath: "/tmp/macgit-orphan-worktree")
        let store = WorktreeLabelStore()

        try store.setLabel("Keep", for: keptPath, in: gitDirectory)
        try store.setLabel("Remove", for: orphanPath, in: gitDirectory)

        let pruned = try store.prune(validPaths: Set([keptPath]), in: gitDirectory)

        XCTAssertEqual(pruned, [WorktreeLabelStore.key(for: keptPath): "Keep"])
        XCTAssertEqual(store.labels(in: gitDirectory), [WorktreeLabelStore.key(for: keptPath): "Keep"])
    }

    private func makeTempGitDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-worktree-label-store-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func labelFileURL(in gitDirectory: URL) -> URL {
        gitDirectory
            .appendingPathComponent("macgit", isDirectory: true)
            .appendingPathComponent("worktree-labels.json")
    }
}
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeLabelStoreTests
```

Expected: build fails with `cannot find 'WorktreeLabelStore' in scope`.

## Task 2: Implement WorktreeLabelStore

**Files:**
- Create: `macgit/Services/WorktreeLabelStore.swift`
- Test: `macgitTests/WorktreeLabelStoreTests.swift`

- [x] **Step 1: Create the sidecar store**

Create `macgit/Services/WorktreeLabelStore.swift`:

```swift
import Foundation

struct WorktreeLabelStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func labels(in gitCommonDirectory: URL) -> [String: String] {
        let url = labelsURL(in: gitCommonDirectory)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    func label(for path: URL, in gitCommonDirectory: URL) -> String? {
        labels(in: gitCommonDirectory)[Self.key(for: path)]
    }

    func setLabel(_ label: String?, for path: URL, in gitCommonDirectory: URL) throws {
        var current = labels(in: gitCommonDirectory)
        let trimmed = (label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            current.removeValue(forKey: Self.key(for: path))
        } else {
            current[Self.key(for: path)] = trimmed
        }

        try write(current, in: gitCommonDirectory)
    }

    func removeLabel(for path: URL, in gitCommonDirectory: URL) throws {
        var current = labels(in: gitCommonDirectory)
        current.removeValue(forKey: Self.key(for: path))
        try write(current, in: gitCommonDirectory)
    }

    func moveLabel(from oldPath: URL, to newPath: URL, in gitCommonDirectory: URL) throws {
        var current = labels(in: gitCommonDirectory)
        let oldKey = Self.key(for: oldPath)
        guard let label = current.removeValue(forKey: oldKey) else {
            try write(current, in: gitCommonDirectory)
            return
        }

        current[Self.key(for: newPath)] = label
        try write(current, in: gitCommonDirectory)
    }

    @discardableResult
    func prune(validPaths: Set<URL>, in gitCommonDirectory: URL) throws -> [String: String] {
        let validKeys = Set(validPaths.map(Self.key(for:)))
        let current = labels(in: gitCommonDirectory)
        let pruned = current.filter { validKeys.contains($0.key) }

        if pruned != current {
            try write(pruned, in: gitCommonDirectory)
        }

        return pruned
    }

    static func key(for path: URL) -> String {
        var normalized = path.standardizedFileURL.path
        if normalized.hasPrefix("/private/") {
            normalized = String(normalized.dropFirst("/private".count))
        }
        return normalized
    }

    private func labelsURL(in gitCommonDirectory: URL) -> URL {
        gitCommonDirectory
            .appendingPathComponent("macgit", isDirectory: true)
            .appendingPathComponent("worktree-labels.json")
    }

    private func write(_ labels: [String: String], in gitCommonDirectory: URL) throws {
        let url = labelsURL(in: gitCommonDirectory)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(labels)
        try data.write(to: url, options: .atomic)
    }
}
```

- [x] **Step 2: Run store tests to verify pass**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeLabelStoreTests
```

Expected: `WorktreeLabelStoreTests` pass.

- [x] **Step 3: Commit the store**

Run:

```bash
git add macgit/Services/WorktreeLabelStore.swift macgitTests/WorktreeLabelStoreTests.swift
git commit -m "feat: add worktree label store"
```

## Task 3: Merge Labels Through GitStatusService

**Files:**
- Modify: `macgit/Services/GitStatusService+Worktree.swift`
- Modify: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add failing service integration tests**

Append these tests inside `final class WorktreeServiceTests` before the helper methods:

```swift
    func testWorktreesWithLabelsMergesStoredLabel() async throws {
        let repoURL = try makeTempRepo()
        let wtPath = repoURL.deletingLastPathComponent().appendingPathComponent("wt-\(UUID().uuidString)")
        try runGit(["worktree", "add", wtPath.path, "feature"], in: repoURL)

        let gitDirectory = try await GitStatusService.shared.gitCommonDirectory(in: repoURL)
        try WorktreeLabelStore().setLabel("Review UI", for: wtPath, in: gitDirectory)

        let entries = await GitStatusService.shared.worktreesWithLabels(in: repoURL)

        XCTAssertEqual(entries.first(where: { $0.path.path == wtPath.path })?.label, "Review UI")
        XCTAssertEqual(entries.first(where: { $0.path.path == wtPath.path })?.displayTitle, "Review UI")
    }

    func testWorktreesWithLabelsPrunesOrphanedLabel() async throws {
        let repoURL = try makeTempRepo()
        let wtPath = repoURL.deletingLastPathComponent().appendingPathComponent("wt-\(UUID().uuidString)")
        let orphanPath = repoURL.deletingLastPathComponent().appendingPathComponent("missing-\(UUID().uuidString)")
        try runGit(["worktree", "add", wtPath.path, "feature"], in: repoURL)

        let gitDirectory = try await GitStatusService.shared.gitCommonDirectory(in: repoURL)
        let store = WorktreeLabelStore()
        try store.setLabel("Review UI", for: wtPath, in: gitDirectory)
        try store.setLabel("Gone", for: orphanPath, in: gitDirectory)

        let entries = await GitStatusService.shared.worktreesWithLabels(in: repoURL)

        XCTAssertEqual(entries.first(where: { $0.path.path == wtPath.path })?.label, "Review UI")
        XCTAssertNil(store.label(for: orphanPath, in: gitDirectory))
    }

    func testSetWorktreeLabelPostsRepositoryDidChangeAndPersistsLabel() async throws {
        let repoURL = try makeTempRepo()
        let wtPath = repoURL.deletingLastPathComponent().appendingPathComponent("wt-\(UUID().uuidString)")
        try runGit(["worktree", "add", wtPath.path, "feature"], in: repoURL)

        let expectation = expectation(forNotification: .repositoryDidChange, object: nil) { notification in
            (notification.userInfo?["repositoryURL"] as? URL)?.path == repoURL.path
        }

        try await GitStatusService.shared.setWorktreeLabel("Agent task", for: wtPath, in: repoURL)

        await fulfillment(of: [expectation], timeout: 1.0)
        let gitDirectory = try await GitStatusService.shared.gitCommonDirectory(in: repoURL)
        XCTAssertEqual(WorktreeLabelStore().label(for: wtPath, in: gitDirectory), "Agent task")
    }
```

- [x] **Step 2: Run service tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: build fails with missing `gitCommonDirectory(in:)`, `worktreesWithLabels(in:)`, and `setWorktreeLabel(_:for:in:)`.

- [x] **Step 3: Add label-aware service helpers**

Append this extension block to `macgit/Services/GitStatusService+Worktree.swift`, below the existing `extension GitStatusService` implementation:

```swift
extension GitStatusService {
    func gitCommonDirectory(in repositoryURL: URL) async throws -> URL {
        let output = try await runGit(
            arguments: ["rev-parse", "--path-format=absolute", "--git-common-dir"],
            in: repositoryURL
        )
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedWorktreeURL(from: path)
    }

    func worktreesWithLabels(in repositoryURL: URL) async -> [WorktreeEntry] {
        let entries = await worktrees(in: repositoryURL)
        guard let gitDirectory = try? await gitCommonDirectory(in: repositoryURL) else {
            return entries
        }

        let store = WorktreeLabelStore()
        let labels = (try? store.prune(validPaths: Set(entries.map(\.path)), in: gitDirectory))
            ?? store.labels(in: gitDirectory)

        return entries.map { entry in
            var labeled = entry
            labeled.label = labels[WorktreeLabelStore.key(for: entry.path)]
            return labeled
        }
    }

    func setWorktreeLabel(_ label: String?, for path: URL, in repositoryURL: URL) async throws {
        let gitDirectory = try await gitCommonDirectory(in: repositoryURL)
        try WorktreeLabelStore().setLabel(label, for: path, in: gitDirectory)
        NotificationCenter.default.post(
            name: .repositoryDidChange,
            object: nil,
            userInfo: ["repositoryURL": repositoryURL]
        )
    }

    func removeWorktreeLabel(for path: URL, in repositoryURL: URL) async throws {
        let gitDirectory = try await gitCommonDirectory(in: repositoryURL)
        try WorktreeLabelStore().removeLabel(for: path, in: gitDirectory)
        NotificationCenter.default.post(
            name: .repositoryDidChange,
            object: nil,
            userInfo: ["repositoryURL": repositoryURL]
        )
    }
}
```

- [x] **Step 4: Run service tests to verify pass**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: `WorktreeServiceTests` pass.

- [x] **Step 5: Commit service merge support**

Run:

```bash
git add macgit/Services/GitStatusService+Worktree.swift macgitTests/WorktreeServiceTests.swift
git commit -m "feat: merge worktree labels into entries"
```

## Task 4: Add Sidebar Label Editing

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`
- Test manually by building; UI is not covered by XCTest in this phase.

- [x] **Step 1: Add sidebar label state**

In `SidebarView`, near the existing worktree state:

```swift
    @State private var worktreeEntries: [WorktreeEntry] = []
    @State private var isLoadingWorktrees = false
    @State private var worktreeToLabel: WorktreeEntry?
    @State private var worktreeLabelInput = ""
    @State private var showingWorktreeLabelSheet = false
```

- [x] **Step 2: Present the label sheet**

In the view modifier chain that already contains the `Error` and `Delete Branch` alerts, add:

```swift
        .sheet(isPresented: $showingWorktreeLabelSheet) {
            worktreeLabelSheet
        }
```

- [x] **Step 3: Add the label sheet view**

Add this computed view near the other private view helpers in `SidebarView`:

```swift
    @ViewBuilder
    private var worktreeLabelSheet: some View {
        if let entry = worktreeToLabel {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.label == nil ? "Set Worktree Label" : "Edit Worktree Label")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Worktree:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(entry.path.path)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Label:")
                        .font(.system(size: 13))
                    TextField(entry.branch ?? entry.path.lastPathComponent, text: $worktreeLabelInput)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel", role: .cancel) {
                        showingWorktreeLabelSheet = false
                        worktreeToLabel = nil
                        worktreeLabelInput = ""
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        Task {
                            await saveWorktreeLabel()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(minWidth: 420, idealWidth: 480)
        } else {
            EmptyView()
        }
    }
```

- [x] **Step 4: Add context menu actions**

Update `worktreeContextMenu(for:)` so the first block after Open/Terminal includes label actions:

```swift
    @ViewBuilder
    private func worktreeContextMenu(for entry: WorktreeEntry) -> some View {
        Button("Open in New Window") {
            onRequestOpenWorktree(entry.path)
        }

        Button("Open in Terminal") {
            onRequestOpenWorktreeInTerminal(entry.path)
        }

        Divider()

        Button(entry.label == nil ? "Set Label..." : "Edit Label...") {
            beginEditingWorktreeLabel(entry)
        }

        if entry.label != nil {
            Button("Clear Label") {
                Task {
                    await clearWorktreeLabel(entry)
                }
            }
        }

        Divider()

        Button("Copy Path to Clipboard") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.path.path, forType: .string)
        }
    }
```

- [x] **Step 5: Load labels with worktrees**

Change `loadWorktrees()` to call the label-aware helper:

```swift
    private func loadWorktrees() async {
        isLoadingWorktrees = true
        defer { isLoadingWorktrees = false }

        let entries = await GitStatusService.shared.worktreesWithLabels(in: repositoryURL)
        await MainActor.run {
            worktreeEntries = entries
        }
    }
```

- [x] **Step 6: Add label action methods**

Add these methods near `loadWorktrees()`:

```swift
    private func beginEditingWorktreeLabel(_ entry: WorktreeEntry) {
        worktreeToLabel = entry
        worktreeLabelInput = entry.label ?? ""
        showingWorktreeLabelSheet = true
    }

    private func saveWorktreeLabel() async {
        guard let entry = worktreeToLabel else { return }

        do {
            try await GitStatusService.shared.setWorktreeLabel(worktreeLabelInput, for: entry.path, in: repositoryURL)
            await loadWorktrees()
            await MainActor.run {
                showingWorktreeLabelSheet = false
                worktreeToLabel = nil
                worktreeLabelInput = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func clearWorktreeLabel(_ entry: WorktreeEntry) async {
        do {
            try await GitStatusService.shared.removeWorktreeLabel(for: entry.path, in: repositoryURL)
            await loadWorktrees()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
```

- [x] **Step 7: Build to catch SwiftUI integration errors**

Run:

```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
```

Expected: build succeeds.

- [x] **Step 8: Commit sidebar label UI**

Run:

```bash
git add macgit/Views/MainWindow/SidebarView.swift
git commit -m "feat: edit worktree labels from sidebar"
```

## Task 5: Full Verification and Roadmap Status

**Files:**
- Modify: `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md`

- [x] **Step 1: Run the focused worktree tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeLabelStoreTests -only-testing:macgitTests/WorktreeServiceTests
```

Expected: all selected worktree tests pass.

- [x] **Step 2: Run the full test suite**

Run:

```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test
```

Expected: full test suite passes.

- [x] **Step 3: Update roadmap marker after verification**

After the build and full tests pass, update the Phase 2 line in `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md` from:

```markdown
- Phase 2: [pending] [2026-06-20-worktree-phase-2-label-store.md](2026-06-20-worktree-phase-2-label-store.md)
```

to:

```markdown
- Phase 2: [completed] [2026-06-20-worktree-phase-2-label-store.md](2026-06-20-worktree-phase-2-label-store.md) (branch: `codex/worktree-phase-2-label-store`)
```

If implementation lands on a different branch, use that branch name in the marker.

- [x] **Step 4: Commit roadmap completion marker**

Run:

```bash
git add docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md
git commit -m "docs: mark worktree label phase complete"
```

## Self-Review

Spec coverage:

- Scope item 9, Status/Label, is covered by `WorktreeLabelStore`, `worktreesWithLabels(in:)`, and the sidebar Set/Edit/Clear Label actions.
- The sidecar file location is covered by `WorktreeLabelStore.labelsURL(in:)`, with callers passing the common Git directory from `git rev-parse --path-format=absolute --git-common-dir`.
- Missing and corrupt label files are covered by `testMissingLabelFileReadsAsEmptyDictionary` and `testCorruptLabelFileReadsAsEmptyDictionary`.
- Orphan pruning after list is covered by `testWorktreesWithLabelsPrunesOrphanedLabel`.
- Future Phase 3 create and Phase 4 move/remove reuse is covered by `setLabel`, `removeLabel`, `moveLabel`, and `prune`.

Placeholder scan:

- Every task has concrete files, code snippets, commands, and expected results.
- No step requires unspecified validation or unspecified error handling.

Type consistency:

- `WorktreeEntry.label` and `WorktreeEntry.displayTitle` already exist from Phase 1 and are reused unchanged.
- Service methods are consistently named `gitCommonDirectory(in:)`, `worktreesWithLabels(in:)`, `setWorktreeLabel(_:for:in:)`, and `removeWorktreeLabel(for:in:)`.
- Store path keys consistently use `WorktreeLabelStore.key(for:)`.
