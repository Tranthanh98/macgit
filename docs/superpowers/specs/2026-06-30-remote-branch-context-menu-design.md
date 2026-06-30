# Remote Branch Context Menu Design

## Goal
Add a right-click context menu for remote branch leaf rows in the Sidebar, matching the SourceTree menu layout and behavior.

## Context
- `SidebarView.swift` already supports double-click to checkout a remote branch into a local tracking branch.
- Local branches already have a context menu; remote branches currently only support "Copy Branch Name".
- Git operations are handled by `GitStatusService` and `SyncState`; `MainWindowView` wires callbacks into `SidebarView`.

## Menu Items
For a remote branch row `origin/foo`, the menu will contain, in order:

1. **Checkout...**  
   Checkout the remote branch into a local tracking branch. Uses the existing `checkoutRemoteBranch(remote:branch:in:)` service method. After success, the Branches section is expanded, branches/remotes are reloaded, and the newly created/checked-out local branch is selected.

2. **Pull `origin/foo` into `<current>`**  
   Pull the remote branch into the current branch via `SyncState.performPull(remote:branch:options:repositoryURL:undoManager:)`.

3. **Copy Branch Name to Clipboard**

4. **Diff Against Current**  
   Disabled. Will be implemented later alongside the same feature for local branches.

5. **Delete...**  
   Shows a confirmation alert, then deletes the remote branch with `GitStatusService.deleteRemoteBranch(remote:name:in:)`. On success, remotes are reloaded and selection falls back to History if the deleted row was selected.

6. **Create Pull Request...**  
   Opens a pull request URL using `PullRequestURLBuilder` with the remote URL and branch name.

## Disable Rules
- Any item operating on a branch named `HEAD` is disabled (`Checkout...`, `Delete...`, `Create Pull Request...`).
- `Pull ... into ...` is disabled when there is no current branch or the remote branch is `HEAD`.

## Error Handling
Failures from Git operations are surfaced through `SidebarView`’s existing `errorMessage` + `showingError` alert.

## Scope
- Only the remote branch context menu in `SidebarView` is changed.
- No new service methods are introduced; existing helpers are reused.
- "Diff Against Current" remains disabled, consistent with local branches.

## Verification
- `xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test` must pass.
