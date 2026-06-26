# Worktree Phase 4: Lock, Prune, Move, and Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Complete v1 worktree management by adding lock/unlock, prune, move/rename, and branch-switch operations to the existing `WORKTREES` sidebar and `GitStatusService+Worktree` surface.

**Architecture:** Extend `GitStatusService+Worktree` with one focused async API per Git operation, keeping all Git subprocess calls inside the service and posting `.repositoryDidChange` only after successful mutations. Reuse Phase 2 `WorktreeLabelStore` for move/prune sidecar maintenance and extend the Phase 3 sidebar action patterns with small dialogs/sheets for reason, destination path, and target branch input.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, existing `GitStatusService`, `WorktreeEntry`, `WorktreeLabelStore`, `git worktree lock`, `git worktree unlock`, `git worktree prune`, `git worktree move`, and `git -C <worktree> checkout`.

**Roadmap:** [docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md](2026-06-20-worktree-management-roadmap.md)
**Design spec:** [docs/superpowers/specs/2026-06-20-worktree-management-design.md](../specs/2026-06-20-worktree-management-design.md)

---

## Prerequisite

Phases 1-3 must already be merged. The codebase should contain:

- `macgit/Services/WorktreeEntry.swift`
- `macgit/Services/GitStatusService+Worktree.swift` with `worktrees(in:)`, `worktreesWithLabels(in:)`, `gitCommonDirectory(in:)`, `setWorktreeLabel(_:for:in:)`, `removeWorktreeLabel(for:in:)`, `addWorktree(at:target:label:in:)`, and `removeWorktree(at:force:in:)`
- `macgit/Services/WorktreeLabelStore.swift` with `moveLabel(from:to:in:)` and `prune(validPaths:in:)`
- `macgit/Views/MainWindow/SidebarView.swift` with the `WORKTREES` section, label actions, create sheet, and guarded remove action
- `macgitTests/WorktreeServiceTests.swift`
- `macgitTests/WorktreeLabelStoreTests.swift`

## Scope

This phase supports:

- Locking linked worktrees with an optional reason.
- Unlocking linked worktrees.
- Pruning stale Git worktree metadata and orphaned label sidecar entries.
- Moving/renaming linked worktrees to a new path and moving the label sidecar key only after Git succeeds.
- Switching the branch checked out inside a linked worktree.
- Guarding branch switch when the linked worktree is dirty unless the user confirms force checkout.
- Posting `.repositoryDidChange` after every successful mutation.
- Keeping the main worktree non-lockable, non-movable, and branch-switchable only through existing app branch actions, not the worktree sidebar row.

This phase does NOT add worktree undo/redo, busy process detection, templates, tabs, or sync-status aggregation across worktrees.

## File Structure

- Modify `macgit/Services/GitStatusService+Worktree.swift`: add lock, unlock, prune, move, and checkout service APIs plus reusable main-worktree/path guards if needed.
- Modify `macgit/Views/MainWindow/SidebarView.swift`: add context menu actions, lock reason dialog, move sheet, checkout sheet, prune header action, and action handlers.
- Optionally create `macgit/Views/Common/WorktreeMoveSheetView.swift`: use this only if the move sheet makes `SidebarView` materially harder to read.
- Optionally create `macgit/Views/Common/WorktreeCheckoutSheetView.swift`: use this only if the checkout sheet needs enough state to justify extraction.
- Modify `macgitTests/WorktreeServiceTests.swift`: add lock/unlock, prune, move, and checkout integration tests against real temp repos.
- Modify `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md`: keep Phase 4 marked `[pending]` until implementation and tests pass, then update it to `[completed]`.

## Task 1: Add Failing Service Tests for Lock and Unlock

**Files:**
- Modify: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add a helper assertion for linked worktree lookup**

Add a small helper in `WorktreeServiceTests` if one does not already exist:

```swift
private func linkedWorktree(at path: URL, in entries: [WorktreeEntry]) -> WorktreeEntry? {
    entries.first { WorktreeLabelStore.key(for: $0.path) == WorktreeLabelStore.key(for: path) }
}
```

- [x] **Step 2: Add a lock-with-reason test**

Create a temp repo, add a linked worktree with the existing Phase 3 API, then call:

```swift
try await GitStatusService.shared.lockWorktree(
    at: wtPath,
    reason: "Long running agent task",
    in: repoURL
)
```

Assert:

- `.repositoryDidChange` is posted with `repositoryURL`.
- `worktrees(in:)` includes `wtPath`.
- The linked entry has `isLocked == true`.
- `git worktree list --porcelain` output contains `locked Long running agent task`.

- [x] **Step 3: Add a lock-without-reason test**

Call:

```swift
try await GitStatusService.shared.lockWorktree(
    at: wtPath,
    reason: nil,
    in: repoURL
)
```

Assert:

- The linked entry has `isLocked == true`.
- The operation succeeds without adding an empty `--reason` argument.

- [x] **Step 4: Add an unlock test**

Lock the linked worktree through the CLI setup command:

```swift
try runGit(["worktree", "lock", wtPath.path], in: repoURL)
```

Then call:

```swift
try await GitStatusService.shared.unlockWorktree(at: wtPath, in: repoURL)
```

Assert:

- `.repositoryDidChange` is posted with `repositoryURL`.
- `worktrees(in:)` includes `wtPath`.
- The linked entry has `isLocked == false`.

- [x] **Step 5: Add main worktree guard tests**

Assert both calls throw before mutating Git state:

```swift
try await GitStatusService.shared.lockWorktree(at: repoURL, reason: "no", in: repoURL)
try await GitStatusService.shared.unlockWorktree(at: repoURL, in: repoURL)
```

The main worktree must remain listed and unlocked.

- [x] **Step 6: Run the focused tests and verify failure**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: build fails because `lockWorktree` and `unlockWorktree` do not exist yet.

## Task 2: Implement Lock and Unlock APIs

**Files:**
- Modify: `macgit/Services/GitStatusService+Worktree.swift`
- Test: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add public lock API**

Implement:

```swift
func lockWorktree(at path: URL, reason: String?, in repositoryURL: URL) async throws
```

Behavior:

- Reject the main worktree by reusing the same normalized path comparison used by `removeWorktree(at:force:in:)`.
- Trim `reason`.
- Run `git worktree lock <path>` when the trimmed reason is empty.
- Run `git worktree lock --reason <reason> <path>` when the trimmed reason is nonempty.
- Post `.repositoryDidChange` only after Git succeeds.

- [x] **Step 2: Add public unlock API**

Implement:

```swift
func unlockWorktree(at path: URL, in repositoryURL: URL) async throws
```

Behavior:

- Reject the main worktree.
- Run `git worktree unlock <path>`.
- Post `.repositoryDidChange` only after Git succeeds.

- [x] **Step 3: Keep argument ordering explicit**

Prefer one clear argument build per command:

```swift
var arguments = ["worktree", "lock"]
if let reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
    arguments.append("--reason")
    arguments.append(reason)
}
arguments.append(path.path)
```

- [x] **Step 4: Run focused lock/unlock tests**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: lock/unlock tests pass; later Phase 4 tests are not added yet.

## Task 3: Add Failing Service Tests for Prune

**Files:**
- Modify: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add prune stale worktree test**

Create a linked worktree, then remove its directory outside the service:

```swift
try FileManager.default.removeItem(at: wtPath)
try await GitStatusService.shared.pruneWorktrees(in: repoURL)
```

Assert:

- `.repositoryDidChange` is posted with `repositoryURL`.
- `git worktree list --porcelain` no longer includes `wtPath.path`.
- `worktrees(in:)` no longer includes `wtPath`.

- [x] **Step 2: Add prune orphan label test**

Create a linked worktree with a label, remove its directory outside the service, then call:

```swift
try await GitStatusService.shared.pruneWorktrees(in: repoURL)
```

Assert:

- `WorktreeLabelStore().label(for: wtPath, in: gitDirectory)` is `nil`.
- Labels for still-valid worktree paths are preserved.

- [x] **Step 3: Add prune no-op test**

Call prune when all worktree paths still exist.

Assert:

- The command succeeds.
- Existing labels are preserved.
- A repository change notification is posted so the sidebar refreshes consistently after the user requested prune.

- [x] **Step 4: Run the focused tests and verify failure**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: build fails because `pruneWorktrees(in:)` does not exist yet.

## Task 4: Implement Prune API

**Files:**
- Modify: `macgit/Services/GitStatusService+Worktree.swift`
- Test: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add public prune API**

Implement:

```swift
func pruneWorktrees(in repositoryURL: URL) async throws
```

Behavior:

- Run `git worktree prune` in `repositoryURL`.
- After Git succeeds, call `worktrees(in:)` to get current valid paths.
- Resolve `gitCommonDirectory(in:)`.
- Call `WorktreeLabelStore().prune(validPaths: Set(entries.map(\.path)), in: gitDirectory)`.
- Post `.repositoryDidChange` only after Git and label pruning succeed.

- [x] **Step 2: Preserve labels if Git prune fails**

Make sure label pruning happens only after `runGit(arguments: ["worktree", "prune"], in: repositoryURL)` succeeds.

- [x] **Step 3: Run focused prune tests**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: prune tests pass; move and checkout tests are not added yet.

## Task 5: Add Failing Service Tests for Move/Rename

**Files:**
- Modify: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add move success test**

Create a linked worktree and label it, then call:

```swift
try await GitStatusService.shared.moveWorktree(
    from: oldPath,
    to: newPath,
    in: repoURL
)
```

Assert:

- `.repositoryDidChange` is posted with `repositoryURL`.
- The old path no longer exists.
- The new path exists.
- `worktreesWithLabels(in:)` includes `newPath`.
- The moved entry keeps the old label.
- `WorktreeLabelStore().label(for: oldPath, in: gitDirectory)` is `nil`.
- `WorktreeLabelStore().label(for: newPath, in: gitDirectory)` equals the original label.

- [x] **Step 2: Add move target-exists failure test**

Create the target directory before calling `moveWorktree(from:to:in:)`.

Assert:

- The service throws.
- The old path still exists.
- The target directory is not converted into a worktree.
- The label remains keyed to the old path.
- No successful mutation notification is posted.

- [x] **Step 3: Add move main worktree guard test**

Assert:

```swift
try await GitStatusService.shared.moveWorktree(from: repoURL, to: newPath, in: repoURL)
```

throws before Git runs and the main worktree remains listed at `repoURL`.

- [x] **Step 4: Run the focused tests and verify failure**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: build fails because `moveWorktree(from:to:in:)` does not exist yet.

## Task 6: Implement Move/Rename API

**Files:**
- Modify: `macgit/Services/GitStatusService+Worktree.swift`
- Test: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add public move API**

Implement:

```swift
func moveWorktree(from oldPath: URL, to newPath: URL, in repositoryURL: URL) async throws
```

Behavior:

- Reject moving the main worktree.
- Reject empty `newPath.path`.
- If `FileManager.default.fileExists(atPath: newPath.path)` is true, throw `GitError.commandFailed("Target path already exists.")` before running Git.
- Run `git worktree move <oldPath> <newPath>`.
- Resolve `gitCommonDirectory(in:)`.
- Call `WorktreeLabelStore().moveLabel(from: oldPath, to: newPath, in: gitDirectory)` only after Git succeeds.
- Post `.repositoryDidChange` only after Git and label update succeed.

- [x] **Step 2: Preserve label on Git failure**

Do not call `moveLabel(from:to:in:)` until after `git worktree move` succeeds. A failed move must leave the sidecar untouched.

- [x] **Step 3: Run focused move tests**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: move tests pass; checkout tests are not added yet.

## Task 7: Add Failing Service Tests for Branch Checkout

**Files:**
- Modify: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add clean checkout test**

Create two branches and a linked worktree, then call:

```swift
try await GitStatusService.shared.checkoutBranch(
    "release",
    inWorktree: wtPath,
    force: false,
    repositoryURL: repoURL
)
```

Assert:

- `.repositoryDidChange` is posted with `repositoryURL`.
- `git -C <wtPath> branch --show-current` returns `release`.
- `worktrees(in:)` shows the linked entry with `branch == "release"`.

- [x] **Step 2: Add dirty checkout guard test**

Create a linked worktree, write an uncommitted file in it, then call checkout without force.

Assert:

- The service throws.
- The checked-out branch in `wtPath` remains unchanged.
- The dirty file still exists.

- [x] **Step 3: Add dirty checkout force test**

Use the same dirty setup and call:

```swift
try await GitStatusService.shared.checkoutBranch(
    "release",
    inWorktree: wtPath,
    force: true,
    repositoryURL: repoURL
)
```

Assert:

- The checked-out branch becomes `release`.
- The force flag maps to `git -C <worktree> checkout --force <branch>`.

- [x] **Step 4: Add invalid branch failure test**

Call checkout with a missing branch name.

Assert:

- The service throws.
- The linked worktree remains on its original branch.
- No successful mutation notification is posted.

- [x] **Step 5: Run the focused tests and verify failure**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: build fails because the worktree checkout API does not exist yet.

## Task 8: Implement Branch Checkout API

**Files:**
- Modify: `macgit/Services/GitStatusService+Worktree.swift`
- Test: `macgitTests/WorktreeServiceTests.swift`

- [x] **Step 1: Add public checkout API**

Implement:

```swift
func checkoutBranch(
    _ branch: String,
    inWorktree worktreePath: URL,
    force: Bool,
    repositoryURL: URL
) async throws
```

Behavior:

- Trim `branch` and throw `GitError.commandFailed("Branch name is required.")` if empty.
- Build arguments for running in `worktreePath`, not `repositoryURL`.
- Use `["checkout", trimmedBranch]` for normal checkout.
- Use `["checkout", "--force", trimmedBranch]` for force checkout.
- Post `.repositoryDidChange` with the root `repositoryURL` only after Git succeeds.

- [x] **Step 2: Keep worktree checkout separate from existing commit checkout**

Do not change the existing `checkoutCommit(_:force:in:)` flow in `GitStatusService+Diff.swift` or `MainWindowView`. This Phase 4 method is only for switching a branch inside a selected linked worktree row.

- [x] **Step 3: Run focused checkout tests**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests
```

Expected: all Phase 4 service tests pass.

## Task 9: Add Lock, Unlock, and Prune UI

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`

- [x] **Step 1: Add lock dialog state**

Add state for:

- `worktreeToLock: WorktreeEntry?`
- `worktreeLockReason: String`
- `isUpdatingWorktreeLock: Bool`

- [x] **Step 2: Add context menu lock actions**

In `worktreeContextMenu(for:)`:

- For non-main unlocked linked worktrees, show `Lock Worktree...`.
- For non-main locked linked worktrees, show `Unlock Worktree`.
- Do not show lock/unlock actions for the main worktree.

- [x] **Step 3: Add lock reason sheet or alert**

Use a small sheet if a text field is needed. The sheet should include:

- Title: `Lock Worktree`
- Path summary using `entry.path.lastPathComponent`
- Text field placeholder: `Reason`
- Cancel button.
- Lock button disabled while `isUpdatingWorktreeLock` is true.

- [x] **Step 4: Implement lock handler**

On submit:

```swift
try await GitStatusService.shared.lockWorktree(
    at: entry.path,
    reason: worktreeLockReason,
    in: repositoryURL
)
```

Then reload worktrees, clear lock state, and surface errors through the existing `errorMessage` / `showingError` path.

- [x] **Step 5: Implement unlock handler**

On unlock:

```swift
try await GitStatusService.shared.unlockWorktree(at: entry.path, in: repositoryURL)
```

Then reload worktrees and surface errors through the existing alert path.

- [x] **Step 6: Add prune action to the WORKTREES header**

Add a compact `Prune Worktrees` action in the `WORKTREES` header menu or an icon menu next to the existing create button. The action should confirm before running:

```swift
try await GitStatusService.shared.pruneWorktrees(in: repositoryURL)
```

After success, reload worktrees.

- [x] **Step 7: Run a build after UI wiring**

Run:

```bash
rtk xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
```

Expected: build succeeds.

## Task 10: Add Move/Rename UI

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`
- Optional create: `macgit/Views/Common/WorktreeMoveSheetView.swift`

- [x] **Step 1: Add move sheet state**

Add state for:

- `worktreeToMove: WorktreeEntry?`
- `worktreeMovePathInput: String`
- `isMovingWorktree: Bool`
- `worktreeMoveErrorMessage: String?`

- [x] **Step 2: Add context menu move action**

For non-main linked worktrees, show `Rename/Move Worktree...`.

Do not show this action for the main worktree.

- [x] **Step 3: Build the move sheet**

The sheet should include:

- Current path text.
- New path text field initialized to a sibling path based on the current path.
- Inline error text when move fails.
- Cancel and Move buttons.

The Move button should disable while submitting or when the normalized old and new paths match.

- [x] **Step 4: Implement move submit**

On submit:

```swift
try await GitStatusService.shared.moveWorktree(
    from: entry.path,
    to: URL(fileURLWithPath: worktreeMovePathInput),
    in: repositoryURL
)
```

Then reload worktrees, dismiss the sheet, and keep errors inline without dismissing.

- [x] **Step 5: Run a build**

Run:

```bash
rtk xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
```

Expected: build succeeds.

## Task 11: Add Branch Switch UI

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`
- Optional create: `macgit/Views/Common/WorktreeCheckoutSheetView.swift`

- [x] **Step 1: Add checkout sheet state**

Add state for:

- `worktreeToCheckout: WorktreeEntry?`
- `worktreeCheckoutBranch: String`
- `availableWorktreeCheckoutBranches: [String]`
- `isCheckingOutWorktreeBranch: Bool`
- `worktreeCheckoutErrorMessage: String?`
- `pendingWorktreeForceCheckout: WorktreeEntry?`

- [x] **Step 2: Add context menu checkout action**

For non-main linked worktrees, show `Switch Branch...`.

Do not show this action for the main worktree; existing branch checkout commands already target the current repository window.

- [x] **Step 3: Load branch options**

When opening the sheet, call the existing local branch API used by the Phase 3 create sheet:

```swift
let branches = await GitStatusService.shared.localBranches(in: repositoryURL)
```

Use the current linked worktree branch as the initial selection when possible, otherwise use the first branch.

- [x] **Step 4: Build the checkout sheet**

The sheet should include:

- Worktree path summary.
- Branch picker populated from `availableWorktreeCheckoutBranches`.
- Inline error text when checkout fails.
- Cancel and Switch buttons.

The Switch button should disable while submitting or when the selected branch is empty.

- [x] **Step 5: Confirm force checkout for dirty worktrees**

If `entry.dirtyCount > 0`, show a confirmation before calling the service with `force: true`.

Use concise copy:

```text
This worktree has uncommitted changes. Force checkout and discard conflicting changes?
```

For clean worktrees, call the service with `force: false`.

- [x] **Step 6: Implement checkout submit**

On submit:

```swift
try await GitStatusService.shared.checkoutBranch(
    worktreeCheckoutBranch,
    inWorktree: entry.path,
    force: force,
    repositoryURL: repositoryURL
)
```

Then reload worktrees, dismiss the sheet, and surface errors inline or through the existing alert path.

- [x] **Step 7: Run a build**

Run:

```bash
rtk xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
```

Expected: build succeeds.

## Task 12: Verification and Roadmap Update

**Files:**
- Modify: `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md`
- All modified code/test files

- [x] **Step 1: Run focused worktree tests**

Run:

```bash
rtk xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/WorktreeServiceTests -only-testing:macgitTests/WorktreeLabelStoreTests
```

Expected: all focused worktree tests pass.

- [x] **Step 2: Run the full test suite**

Run:

```bash
rtk xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test
```

Per project instructions, do not launch the app after a successful build/test run.

- [x] **Step 3: Update this plan**

After tests are green, mark completed checkboxes in this plan for the steps actually executed.

- [x] **Step 4: Update the roadmap**

Update `docs/superpowers/plans/2026-06-20-worktree-management-roadmap.md` Phase 4 from `[pending]` to `[completed]` and include the branch name or merge commit:

```markdown
- Phase 4: [completed] [2026-06-20-worktree-phase-4-lock-prune-move-checkout.md](2026-06-20-worktree-phase-4-lock-prune-move-checkout.md) (branch: `codex/worktree-phase-4-lock-prune-move-checkout`)
```

## Self-Review

Spec coverage:

- Covers Phase 4 lock/unlock with optional reason, prune stale metadata, prune orphan labels, move/rename with label key update, and switch branch inside a linked worktree.
- Reuses the Phase 1 sidebar/list model, Phase 2 label store, and Phase 3 create/remove UI/service patterns.
- Keeps the main worktree protected from worktree-only destructive operations.

Safety:

- Labels are moved or pruned only after Git succeeds.
- Main worktree lock/unlock/move actions are guarded in service and hidden in UI.
- Dirty worktree branch switching requires explicit force confirmation.
- Every successful mutation posts `.repositoryDidChange`.

Testing:

- Service tests use real temp Git repos and CLI-created setup state, matching earlier worktree tests.
- UI work is build-verified; manual app launch is intentionally left to the user per project instructions.
