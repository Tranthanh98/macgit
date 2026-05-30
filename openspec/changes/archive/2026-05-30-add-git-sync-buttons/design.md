## Context
macgit is a single-module SwiftUI macOS app that invokes Git via `Process`. The main toolbar already shows Commit, Pull, Push, and Fetch buttons, but they are wired to empty closures. `GitStatusService` already supports `push` and `status`, but lacks `pull`, `fetch`, and ahead/behind count queries.

## Goals / Non-Goals
- Goals:
  - Make Commit, Push, Pull, and Fetch toolbar buttons functional.
  - Provide numeric badges on Commit, Push, and Pull buttons.
  - Surface Git errors and merge conflicts via native macOS alerts.
  - Keep the Pull badge accurate with a lightweight background sync mechanism.
- Non-Goals:
  - Implement Branch, Merge, Stash toolbar buttons (they remain placeholders).
  - Build a custom merge-conflict resolution UI beyond existing "Resolve Using Ours/Theirs" context menu.
  - SSH credential management or keychain integration.
  - Support for multiple remotes or complex upstream mappings (assumes simple `origin/<branch>`).

## Decisions
- **Badge data source**: Badges are driven from a shared `@ObservableObject` (tentatively `SyncState`) that queries `GitStatusService` on a timer and on every manual action. This centralizes counts and avoids duplicating Git logic in views.
- **Background sync**: A 60-second `Timer` running on the main actor (or via `Task` with `Task.sleep`) triggers `git fetch` followed by ahead/behind and status queries. `git fetch` is preferred over `git ls-remote` because it updates remote-tracking branches, making ahead/behind counts trivial and reliable.
- **Error surfacing**: All Git CLI errors are caught as `GitError.commandFailed`, forwarded to `SyncState`, and displayed via a single `.alert` modifier attached to `MainWindowView` so any toolbar or sheet action can share it.
- **Conflict detection**: Before executing Push, Pull, or Commit, `SyncState` checks the latest `GitStatus` for any `FileStatus.conflict` entries. If found, an alert is presented and the action is cancelled. During Pull, if the command fails with stderr containing "CONFLICT", a conflict-specific alert is shown.

## Risks / Trade-offs
- **Background fetch may prompt for SSH credentials** if the user hasn’t cached them. Mitigation: background fetch failures are silently swallowed (logged to Console if needed) so the UI never hangs on a credential prompt. The user must perform at least one manual Fetch to cache credentials.
- **Timer-based polling is simple but not real-time**. Mitigation: 60-second interval is a reasonable default for a desktop Git client; manual actions immediately refresh counts.
- **Badge count accuracy with detached HEAD or no upstream**. Mitigation: if the branch has no upstream, Push and Pull badges show 0 (hidden).

## Migration Plan
No breaking changes. The new `SyncState` object is additive. Existing `FileStatusView` commit bar continues to work independently; it may optionally observe `SyncState` for counts.

## Open Questions
- Should the Commit badge count only staged files or all working-directory changes? (Proposal assumes all changes for maximum visibility.)
- Should Fetch also trigger a refresh of the Pull badge immediately? (Proposal assumes yes.)
