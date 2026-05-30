# Change: Add Working Git Sync Buttons with Badges and Error/Conflict Popups

## Why
The main toolbar currently displays Commit, Pull, Push, and Fetch buttons, but they are non-functional (empty actions). Users need these core Git remote-sync actions to execute real commands, show visual feedback on pending operations via numeric badges, and surface errors or merge conflicts through native popups.

## What Changes
- Wire the Commit, Pull, Push, and Fetch toolbar buttons to execute the corresponding Git CLI commands.
- Add numeric badges to the Commit, Push, and Pull toolbar buttons showing pending counts (capped at 99+).
- Show a native alert popup when any Git command fails.
- Show a native alert popup when merge conflicts are detected in the working directory or arise during Pull.
- Implement a periodic background `git fetch` (every 60 seconds) to keep the Pull badge count accurate.
- Add `pull`, `fetch`, and ahead/behind count helpers to `GitStatusService`.

## Impact
- Affected specs: `main-window` (toolbar UI), `file-status` (background sync and conflict detection), `git-remote-sync` (new capability for Push/Pull/Fetch backend operations)
- Affected code:
  - `macgit/Views/MainWindow/MainWindowView.swift`
  - `macgit/Views/Common/ToolbarButton.swift`
  - `macgit/Services/GitStatusService.swift`
  - `macgit/Views/FileStatus/FileStatusView.swift`
  - Potential new `SyncState` observable object for badge data

## Assumptions
- **Commit badge** counts all working-directory changes: staged + unstaged + untracked files.
- **Push badge** counts commits the current local branch is ahead of its upstream (`@{upstream}`).
- **Pull badge** counts commits the upstream is ahead of the current local branch (`HEAD..@{upstream}`), refreshed by periodic background `git fetch`.
- **Conflict popup** is shown:
  1. When the user triggers Push/Pull/Commit and conflicted files exist in the working directory (action is aborted).
  2. When a Pull operation results in merge conflicts.
- Background fetch uses a 60-second `Timer` and fails silently if credentials are not cached, to avoid blocking the UI.
