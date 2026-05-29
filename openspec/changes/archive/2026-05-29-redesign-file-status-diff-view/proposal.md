# Change: Redesign File Status with Diff View

## Why
The current File status view is a simple list without the ability to preview changes before staging or committing. SourceTree-style split-pane layouts are the standard for Git clients because they let users see what changed in each file while managing the staging area.

## What Changes
- Redesign `FileStatusView` into a two-panel layout:
  - **Left panel**: File list with two sections — Staged (top) and Changed (bottom)
  - Each row has a checkbox to quickly stage/unstage files
  - Clicking a file selects it
  - **Right panel**: Diff viewer showing line-by-line changes for the selected file
    - Added lines in green, removed lines in red, context lines in neutral
    - Show old/new line numbers
- Add `GitDiffService` to parse `git diff` output into hunks/lines
- Remove the old `FileStatusRow` context-menu approach; replace with checkbox interactions
- Keep the existing macOS 26 visual style

## Impact
- Affected specs: `file-status` (modify existing capability)
- Affected code:
  - `macgit/FileStatusView.swift` — complete redesign into two-panel layout
  - `macgit/MainWindowView.swift` — remove commit sheet binding from FileStatusView (keep toolbar)
  - New: `macgit/GitDiffService.swift` — parse unified diff into displayable hunks
  - New: `macgit/DiffView.swift` — diff rendering component
  - Remove: `macgit/FileStatusRow.swift` — replaced by inline layout in FileStatusView
- No breaking changes to repo-picker, sidebar, or other views.
