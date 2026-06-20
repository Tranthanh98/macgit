# Git Undo Phase 1B Hunks and Lines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Git Undo from file-level stage/unstage to hunk-level and selected-line stage/unstage actions.

**Architecture:** Extract the existing private patch-string logic from `GitStatusService+Stage.swift` into a tested `DiffPatchBuilder`. Extend `GitUndoOperation` and `GitUndoExecutor` with an `applyPatch` operation so undo/redo can replay the exact same patch against the index.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `git apply --cached`.

---

## Prerequisite

Complete and merge Phase 0 + 1A from `docs/superpowers/plans/2026-06-19-git-undo-phase-0-1a.md`.

## File Structure

- Create `macgit/Services/DiffPatchBuilder.swift`: testable builder for whole-hunk and selected-line patch strings.
- Create `macgitTests/DiffPatchBuilderTests.swift`: verifies exact patch output and selected-line hunk headers.
- Modify `macgit/Services/GitUndoModels.swift`: add `applyPatch(patch:cached:reverse:)`.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute patch operations through `GitStatusService.applyPatch`.
- Modify `macgit/Services/GitStatusService+Stage.swift`: replace private patch-string helpers with `DiffPatchBuilder` and expose `applyPatch`.
- Modify `macgit/Views/Common/DiffView.swift`: register undo entries for hunk and line stage/unstage actions.
- Create `macgitTests/GitUndoPatchExecutorTests.swift`: verifies executor sends patch input with the right flags.
- Create `macgitTests/GitUndoHunkIntegrationTests.swift`: verifies real hunk stage/unstage undo and redo in a temporary repo.

## Task 1: Extract Patch Builder

**Files:**
- Create: `macgit/Services/DiffPatchBuilder.swift`
- Create: `macgitTests/DiffPatchBuilderTests.swift`
- Modify: `macgit/Services/GitStatusService+Stage.swift`

- [ ] **Step 1: Write failing patch-builder tests**

Create `macgitTests/DiffPatchBuilderTests.swift`:

```swift
import XCTest
@testable import macgit

final class DiffPatchBuilderTests: XCTestCase {
    func testWholeHunkPatchIncludesFileHeadersAndHunkLines() {
        let hunk = DiffHunk(
            header: "@@ -1,2 +1,2 @@",
            lines: [
                DiffLine(oldLineNumber: 1, newLineNumber: 1, text: "old", type: .removed),
                DiffLine(oldLineNumber: nil, newLineNumber: 1, text: "new", type: .added),
                DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "same", type: .context)
            ]
        )

        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: "Sources/App.swift")

        XCTAssertEqual(patch, """
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1,2 +1,2 @@
        -old
        +new
         same

        """)
    }

    func testSelectedLinePatchRecomputesHeaderCounts() {
        let removed = DiffLine(oldLineNumber: 1, newLineNumber: nil, text: "remove me", type: .removed)
        let added = DiffLine(oldLineNumber: nil, newLineNumber: 1, text: "add me", type: .added)
        let ignored = DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "ignore me", type: .added)
        let hunk = DiffHunk(
            header: "@@ -1,3 +1,3 @@",
            lines: [
                removed,
                DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "context", type: .context),
                added,
                ignored
            ]
        )

        let patch = DiffPatchBuilder.patchString(
            for: hunk,
            selectedLines: [removed, added],
            filePath: "README.md"
        )

        XCTAssertEqual(patch, """
        --- a/README.md
        +++ b/README.md
        @@ -1,2 +1,2 @@
        -remove me
         context
        +add me

        """)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/DiffPatchBuilderTests
```

Expected: compilation fails with `cannot find 'DiffPatchBuilder' in scope`.

- [ ] **Step 3: Create `DiffPatchBuilder`**

Create `macgit/Services/DiffPatchBuilder.swift`:

```swift
//
//  DiffPatchBuilder.swift
//  macgit
//

import Foundation

enum DiffPatchBuilder {
    static func patchString(for hunk: DiffHunk, filePath: String) -> String {
        let linesString = hunk.lines.map { line in
            switch line.type {
            case .added: return "+\(line.text)"
            case .removed: return "-\(line.text)"
            case .context: return " \(line.text)"
            case .header: return line.text
            case .conflictMarker: return " \(line.text)"
            }
        }.joined(separator: "\n")
        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(hunk.header)\n\(linesString)\n"
    }

    static func patchString(for hunk: DiffHunk, selectedLines: [DiffLine], filePath: String) -> String {
        let selectedIDs = Set(selectedLines.map(\.id))
        var oldCount = 0
        var newCount = 0
        var filteredLines: [String] = []

        for line in hunk.lines {
            switch line.type {
            case .context:
                filteredLines.append(" \(line.text)")
                oldCount += 1
                newCount += 1
            case .added:
                if selectedIDs.contains(line.id) {
                    filteredLines.append("+\(line.text)")
                    newCount += 1
                }
            case .removed:
                if selectedIDs.contains(line.id) {
                    filteredLines.append("-\(line.text)")
                    oldCount += 1
                }
            case .header:
                filteredLines.append(line.text)
            case .conflictMarker:
                filteredLines.append(" \(line.text)")
                oldCount += 1
                newCount += 1
            }
        }

        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: hunk.header, range: NSRange(hunk.header.startIndex..., in: hunk.header)),
              let oldStartRange = Range(match.range(at: 1), in: hunk.header),
              let newStartRange = Range(match.range(at: 2), in: hunk.header),
              let oldStart = Int(hunk.header[oldStartRange]),
              let newStart = Int(hunk.header[newStartRange]) else {
            return patchString(for: hunk, filePath: filePath)
        }

        let newHeader = "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(newHeader)\n\(filteredLines.joined(separator: "\n"))\n"
    }
}
```

- [ ] **Step 4: Use `DiffPatchBuilder` in `GitStatusService+Stage.swift`**

In `macgit/Services/GitStatusService+Stage.swift`, replace calls to private helpers:

```swift
let patch = patchString(for: hunk, filePath: file.path)
```

with:

```swift
let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file.path)
```

Replace selected-line calls:

```swift
let patch = patchString(for: hunk, selectedLines: lines, filePath: file.path)
```

with:

```swift
let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file.path)
```

Delete the two private `patchString` functions at the bottom of `GitStatusService+Stage.swift`.

- [ ] **Step 5: Run patch-builder tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/DiffPatchBuilderTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Services/DiffPatchBuilder.swift macgit/Services/GitStatusService+Stage.swift macgitTests/DiffPatchBuilderTests.swift
git commit -m "refactor: extract diff patch builder"
```

Expected: commit succeeds.

## Task 2: Execute Patch Undo Operations

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`
- Modify: `macgit/Services/GitStatusService+Stage.swift`
- Create: `macgitTests/GitUndoPatchExecutorTests.swift`

- [ ] **Step 1: Write failing executor tests for patch operations**

Create `macgitTests/GitUndoPatchExecutorTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoPatchExecutorTests: XCTestCase {
    func testApplyPatchOperationUsesPatchRunnerFlags() async throws {
        let runner = RecordingGitRunner()
        let patchRunner = RecordingPatchRunner()
        let executor = GitUndoExecutor(runner: runner, patchRunner: patchRunner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(
            .applyPatch(patch: "patch text", cached: true, reverse: true),
            in: repoURL
        )

        let calls = await patchRunner.recordedCalls()
        XCTAssertEqual(calls, [
            PatchCall(patch: "patch text", directory: repoURL, cached: true, reverse: true)
        ])
        let commandCalls = await runner.recordedCalls()
        XCTAssertTrue(commandCalls.isEmpty)
    }
}

private struct GitCommandCall: Equatable {
    let arguments: [String]
    let directory: URL
}

private actor RecordingGitRunner: GitCommandRunning {
    private var calls: [GitCommandCall] = []

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(GitCommandCall(arguments: arguments, directory: directory))
        return ""
    }

    func recordedCalls() -> [GitCommandCall] {
        calls
    }
}

private struct PatchCall: Equatable {
    let patch: String
    let directory: URL
    let cached: Bool
    let reverse: Bool
}

private actor RecordingPatchRunner: GitPatchApplying {
    private var calls: [PatchCall] = []

    func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool, reverse: Bool) async throws {
        calls.append(PatchCall(patch: patch, directory: repositoryURL, cached: cached, reverse: reverse))
    }

    func recordedCalls() -> [PatchCall] {
        calls
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoPatchExecutorTests
```

Expected: compilation fails with missing `GitPatchApplying`, missing executor initializer `patchRunner:`, and missing `GitUndoOperation.applyPatch`.

- [ ] **Step 3: Extend undo operation and patch protocol**

In `macgit/Services/GitUndoModels.swift`, update `GitUndoOperation`:

```swift
enum GitUndoOperation: Equatable {
    case stageFiles(paths: [String])
    case unstageFiles(paths: [String])
    case applyPatch(patch: String, cached: Bool, reverse: Bool)
}
```

In `macgit/Services/GitCommandRunning.swift`, append:

```swift
protocol GitPatchApplying {
    func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool, reverse: Bool) async throws
}

extension GitStatusService: GitPatchApplying {}
```

- [ ] **Step 4: Expose `applyPatch` on `GitStatusService`**

In `macgit/Services/GitStatusService+Stage.swift`, change:

```swift
private func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool = false, reverse: Bool = false) async throws {
```

to:

```swift
func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool = false, reverse: Bool = false) async throws {
```

- [ ] **Step 5: Extend the executor**

In `macgit/Services/GitUndoExecutor.swift`, replace the stored properties and initializer:

```swift
private let runner: any GitCommandRunning

init(runner: any GitCommandRunning = GitStatusService.shared) {
    self.runner = runner
}
```

with:

```swift
private let runner: any GitCommandRunning
private let patchRunner: any GitPatchApplying

init(
    runner: any GitCommandRunning = GitStatusService.shared,
    patchRunner: any GitPatchApplying = GitStatusService.shared
) {
    self.runner = runner
    self.patchRunner = patchRunner
}
```

In `execute(_:in:)`, add:

```swift
case .applyPatch(let patch, let cached, let reverse):
    try await patchRunner.applyPatch(patch, in: repositoryURL, cached: cached, reverse: reverse)
```

- [ ] **Step 6: Run executor tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoPatchExecutorTests -only-testing:macgitTests/GitUndoExecutorTests
```

Expected: both executor test classes pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgit/Services/GitCommandRunning.swift macgit/Services/GitStatusService+Stage.swift macgitTests/GitUndoPatchExecutorTests.swift
git commit -m "feat: support patch-based git undo operations"
```

Expected: commit succeeds.

## Task 3: Register Hunk and Line Undo Entries

**Files:**
- Modify: `macgit/Views/Common/DiffView.swift`
- Create: `macgitTests/GitUndoHunkIntegrationTests.swift`

- [ ] **Step 1: Add an undo manager dependency to `DiffView` and `HunkView`**

In `macgit/Views/Common/DiffView.swift`, add this property to `DiffView`:

```swift
let undoManager: GitUndoManager?
```

Pass it into `HunkView`:

```swift
HunkView(
    hunk: hunk,
    file: file,
    repositoryURL: repositoryURL,
    undoManager: undoManager,
    selectedLineIDs: $selectedLineIDs,
    lastSelectedLineID: $lastSelectedLineID,
    onRefresh: onRefresh,
    onError: onError
)
```

Add the same stored property to `HunkView`:

```swift
let undoManager: GitUndoManager?
```

- [ ] **Step 2: Add a helper that performs and records patch actions**

In `HunkView`, add:

```swift
private func performPatchAction(
    label: String,
    patch: String,
    cached: Bool,
    reverse: Bool
) {
    perform {
        try await GitStatusService.shared.applyPatch(
            patch,
            in: repositoryURL!,
            cached: cached,
            reverse: reverse
        )
        await MainActor.run {
            undoManager?.register(
                GitUndoEntry(
                    repositoryURL: repositoryURL!,
                    label: label,
                    undoOperation: .applyPatch(patch: patch, cached: cached, reverse: !reverse),
                    redoOperation: .applyPatch(patch: patch, cached: cached, reverse: reverse)
                )
            )
        }
    }
}
```

- [ ] **Step 3: Replace direct hunk stage/unstage calls**

For staged hunk unstage buttons and menus, replace:

```swift
try await GitStatusService.shared.unstage(hunk: hunk, file: file!, in: repositoryURL!)
```

with:

```swift
let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file!.path)
performPatchAction(label: "Unstage hunk in \(file!.displayName)", patch: patch, cached: true, reverse: true)
```

For unstaged hunk stage buttons and menus, replace:

```swift
try await GitStatusService.shared.stage(hunk: hunk, file: file!, in: repositoryURL!)
```

with:

```swift
let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file!.path)
performPatchAction(label: "Stage hunk in \(file!.displayName)", patch: patch, cached: true, reverse: false)
```

- [ ] **Step 4: Replace direct selected-line stage/unstage calls**

For selected-line unstage actions, use:

```swift
let lines = expandedSelectedLines(for: hunk)
let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file!.path)
performPatchAction(label: "Unstage selected lines in \(file!.displayName)", patch: patch, cached: true, reverse: true)
```

For selected-line stage actions, use:

```swift
let lines = expandedSelectedLines(for: hunk)
let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file!.path)
performPatchAction(label: "Stage selected lines in \(file!.displayName)", patch: patch, cached: true, reverse: false)
```

- [ ] **Step 5: Pass the undo manager from `FileStatusView` to `DiffView`**

In `macgit/Views/FileStatus/FileStatusView.swift`, update the `DiffView` initializer in `diffPanel` to include:

```swift
undoManager: undoManager,
```

- [ ] **Step 6: Write integration test for patch undo**

Create `macgitTests/GitUndoHunkIntegrationTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoHunkIntegrationTests: XCTestCase {
    func testPatchOperationStagesAndUnstagesOneHunk() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("tracked.txt")
        try "one\nchanged\nthree\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let status = try await GitStatusService.shared.status(for: repoURL)
        let file = try XCTUnwrap(status.unstaged.first { $0.path == "tracked.txt" })
        let hunk = try await GitStatusService.shared.diff(for: file, in: repoURL).first!
        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file.path)
        let executor = GitUndoExecutor()

        try await executor.execute(.applyPatch(patch: patch, cached: true, reverse: false), in: repoURL)
        var refreshed = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertTrue(refreshed.staged.contains { $0.path == "tracked.txt" })

        try await executor.execute(.applyPatch(patch: patch, cached: true, reverse: true), in: repoURL)
        refreshed = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertFalse(refreshed.staged.contains { $0.path == "tracked.txt" })
        XCTAssertTrue(refreshed.unstaged.contains { $0.path == "tracked.txt" })
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-hunk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        try "one\ntwo\nthree\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        return repoURL
    }

    private func runGit(_ arguments: [String], in repositoryURL: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL
        let stderr = Pipe()
        task.standardError = stderr
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "git failed"
            XCTFail("git \(arguments.joined(separator: " ")) failed: \(output)")
        }
    }
}
```

- [ ] **Step 7: Run tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/DiffPatchBuilderTests -only-testing:macgitTests/GitUndoPatchExecutorTests -only-testing:macgitTests/GitUndoHunkIntegrationTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: all targeted tests pass and app builds.

- [ ] **Step 8: Commit**

Run:

```bash
git add macgit/Views/Common/DiffView.swift macgit/Views/FileStatus/FileStatusView.swift macgitTests/GitUndoHunkIntegrationTests.swift
git commit -m "feat: record undo entries for hunk staging"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Hunk and selected-line stage/unstage undo is covered through patch extraction, executor support, UI registration, and real-repo tests.

Placeholder scan:

- Every task has concrete files, code snippets, commands, and expected outcomes.

Type consistency:

- `GitUndoOperation.applyPatch` is defined before `GitUndoExecutor` and `DiffView` use it.
- `GitPatchApplying.applyPatch` matches `GitStatusService.applyPatch`.
