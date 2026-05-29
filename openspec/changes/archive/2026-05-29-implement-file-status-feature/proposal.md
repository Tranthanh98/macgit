# Change: Implement File Status Feature

## Why
The macOS Git client currently shows a placeholder for the File status view. To make the application useful, users need to see which files in their working directory have been modified, staged, untracked, or deleted, and be able to take common actions (stage, unstage, discard) directly from the UI.

## What Changes
- Add a Git working-directory status reader (Swift wrapper around `git status --porcelain` or `libgit2` if already integrated).
- Replace the placeholder `FileStatusView` with a real file-list UI grouped into:
  - **Staged** (green)
  - **Unstaged** (red) — includes modified and deleted
  - **Untracked** (grey)
- Add per-row context-menu and/or inline actions:
  - Stage / Unstage
  - Discard changes (with confirmation alert)
- Add a top-level "Commit" button (toolbar) that triggers a commit sheet (message + confirmation).
- Keep the existing macOS 26 visual style (rounded rows, materials, sidebar layout).

## Impact
- Affected specs: `file-status` (new capability)
- Affected code:
  - `macgit/MainWindowView.swift` — toolbar commit button wiring
  - `macgit/FileStatusView.swift` — replace placeholder with real view
  - New: `macgit/GitStatusService.swift` — parse porcelain output and emit model
  - New: `macgit/FileStatusRow.swift` — reusable row component
- No breaking changes to existing repo-picker or sidebar logic.
