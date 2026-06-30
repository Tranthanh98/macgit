# Remote Branch Context Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalize the right-click context menu for remote branch rows in the Sidebar and verify it compiles and passes all tests.

**Architecture:** The menu lives entirely in `SidebarView` and reuses existing service/callback seams (`checkoutRemoteBranch`, `deleteRemoteBranch`, `SyncState.performPull`, `PullRequestURLBuilder`). `MainWindowView` wires the new pull and PR callbacks into `SyncState`/`NSWorkspace`.

**Tech Stack:** Swift, SwiftUI, XCTest, Xcode `xcodebuild`.

---

### Task 1: Inspect current diff and confirm completeness

**Files:**
- Read: `macgit/Views/MainWindow/SidebarView.swift`
- Read: `macgit/Views/MainWindow/MainWindowView.swift`
- Read: `macgit/Services/GitStatusService+Remote.swift`
- Read: `macgitTests/BranchUpstreamServiceTests.swift`

- [ ] **Step 1: Review the current diff**

Run:
```bash
git diff -- macgit/Views/MainWindow/SidebarView.swift macgit/Views/MainWindow/MainWindowView.swift macgit/Services/GitStatusService+Remote.swift macgitTests/BranchUpstreamServiceTests.swift
```

Expected: All six menu items from the SourceTree screenshot are present (`Checkout...`, `Pull ... into ...`, `Copy Branch Name to Clipboard`, `Diff Against Current` disabled, `Delete...`, `Create Pull Request...`), disable rules for `HEAD`/no-current-branch are applied, and callbacks are wired in `MainWindowView`.

- [ ] **Step 2: Check for any TODO/FIXME or obviously incomplete code**

Run:
```bash
rg -n "TODO|FIXME|Diff Against Current" macgit/Views/MainWindow/SidebarView.swift macgit/Views/MainWindow/MainWindowView.swift
```

Expected: No TODO/FIXME. `Diff Against Current` should appear with an empty closure and `.disabled(true)`.

---

### Task 2: Compile the project

**Files:**
- Modify if needed: `macgit/Views/MainWindow/SidebarView.swift`
- Modify if needed: `macgit/Views/MainWindow/MainWindowView.swift`

- [ ] **Step 1: Build the scheme**

Run:
```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
```

Expected: Build succeeds with no Swift compile errors.

- [ ] **Step 2: Fix any compile errors**

If the build fails, read the error message, locate the offending line, and fix the type/signature/closure issue. Common issues:
- Missing `await` inside a `Task` closure calling an async function.
- `SidebarView` initializer default closure mismatch.
- Method name mismatch (e.g., `deleteRemoteBranch` or `performPull` signature).

Re-run Step 1 after each fix until it succeeds.

---

### Task 3: Run the targeted remote-branch test

**Files:**
- Test: `macgitTests/BranchUpstreamServiceTests.swift`

- [ ] **Step 1: Run only the remote branch checkout test**

Run:
```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test -only-testing:macgitTests/BranchUpstreamServiceTests
```

Expected: Test target passes.

- [ ] **Step 2: If it fails, fix the test or implementation**

Read the failure output. If it is an assertion failure, inspect `BranchUpstreamServiceTests.swift`. If it is a compile failure in the test, fix the async assertion pattern (extract `await` results to local variables before asserting). Re-run Step 1.

---

### Task 4: Run the full test suite

**Files:**
- All files under `macgitTests/`

- [ ] **Step 1: Run the complete test suite**

Run:
```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test
```

Expected: Full suite passes with exit code 0.

- [ ] **Step 2: Address any failures**

If any test fails, read the failure log, identify whether it is related to the new code or pre-existing, and fix if related. Re-run Step 1.

---

### Task 5: Final review and status

- [ ] **Step 1: Confirm no unintended changes**

Run:
```bash
git status --short
```

Expected: Only the intended files are modified/created:
- `macgit/Services/GitStatusService+Remote.swift`
- `macgit/Views/MainWindow/SidebarView.swift`
- `macgit/Views/MainWindow/MainWindowView.swift`
- `macgitTests/BranchUpstreamServiceTests.swift`
- `docs/superpowers/specs/2026-06-30-remote-branch-context-menu-design.md`
- `docs/superpowers/plans/2026-06-30-remote-branch-context-menu-plan.md`

- [ ] **Step 2: Do not launch the app**

Per `AGENTS.md`, verification is complete once `xcodebuild` succeeds and unit tests pass. Do not launch the app.
