# Repository Settings Design

## Overview

Add a **repo-specific settings modal** to macgit so each repository can store its own Git behavior preferences and expose a few high-value maintenance actions from the main window toolbar.

The modal opens from the existing `Settings` toolbar button in `MainWindowView` and is intentionally scoped to repository-level concerns only. Global app preferences remain out of scope for this feature and can be implemented separately later.

## Goals

- Open a repository settings modal from the main window toolbar
- Store settings per repository path
- Provide a balanced v1 centered on Git behavior rather than broad app customization
- Keep the modal lightweight with clear sections and native macOS interactions
- Expose quick actions for opening `.gitignore` and `.git/config` in the user's external editor or default app

## Non-Goals

- Global application preferences
- Inline editing of `.gitignore` or `.git/config`
- Advanced branch policy management or automation
- Full repository diagnostics or repair workflows
- Multi-repository settings management

## UX Design

### Presentation

- Trigger: clicking the `Settings` toolbar button in `MainWindowView`
- Container: SwiftUI sheet
- Scope: current repository only
- Actions: `Cancel` and `Save` buttons pinned at the bottom
- File actions: open immediately and do not require pressing `Save`

### Layout

Use **top tabs** with three sections:

1. `Remote`
2. `Pull & Fetch`
3. `Safety & Files`

Top tabs were chosen over a long scrolling form and over sidebar-style tabs because the v1 surface only has three sections and should feel compact.

### Remote Tab

Fields and actions:

- `Default Remote`
  - Populated from detected repository remotes
  - Stored as a string name such as `origin`
- `Default Pull Branch`
  - Uses a hybrid input model:
    - picker of detected branches when available
    - manual text entry fallback for uncommon setups
- `Open Remote URL`
  - Opens the repository's remote URL using the existing external integration behavior

### Pull & Fetch Tab

Fields:

- `Pull Strategy`
  - v1 values: `merge` or `rebase`
- `Auto Fetch`
  - Controls whether background fetch behavior is enabled for this repository
- `Refresh On App Active`
  - Controls whether the repository refreshes when the app becomes active

Notes:

- The UI should stay simple and avoid exposing too many scheduling controls in v1
- If fetch-related controls expand later, this tab can grow without changing the overall modal structure

### Safety & Files Tab

Fields and actions:

- `Confirm Detached HEAD Checkout`
- `Confirm Destructive Stash Actions`
- `Open .gitignore`
- `Open .git/config`

Notes:

- This tab intentionally mixes confirmation preferences with repository maintenance shortcuts because both are low-frequency, advanced actions
- `.gitignore` and `.git/config` are opened in the user's external editor or default handler rather than edited inline

## Data Model

Persist settings per repository path using a dedicated store, separate from sidebar section persistence.

Suggested model:

```swift
struct RepoSettings: Codable {
    var defaultRemoteName: String?
    var defaultPullBranch: String
    var pullStrategy: PullStrategy
    var autoFetchEnabled: Bool
    var refreshOnAppActive: Bool
    var confirmDetachedHeadCheckout: Bool
    var confirmDestructiveStashActions: Bool
}
```

Supporting types:

- `PullStrategy` enum with `merge` and `rebase`
- `RepoSettingsStore` service for loading and saving settings keyed by `repositoryURL.path`

Persistence mechanism:

- `UserDefaults`
- JSON-encoded dictionary keyed by repository path, mirroring the general approach already used by `SidebarSettingsStore`

## Behavior

### Modal Load

When the sheet opens:

- Load saved settings for the current repository path
- If no settings exist yet, use sensible defaults
- Load available remotes and branches from repository data
- Keep the form usable even if branch or remote discovery fails

### Save

When the user clicks `Save`:

- Trim and normalize text inputs where appropriate
- Persist the updated settings to `RepoSettingsStore`
- Dismiss the sheet

`Cancel` dismisses without persisting changes made during the session.

### Branch and Remote Inputs

- Remote choices should reflect current repository remotes if available
- Default pull branch should support both:
  - selecting a known branch
  - entering a manual branch name
- Empty or unavailable branch/remote lists must not block the sheet from opening

### File Actions

`Open .gitignore`:

- Target path: `<repo>/.gitignore`
- If missing, create an empty file first, then open it externally

`Open .git/config`:

- Target path: `<repo>/.git/config`
- Only open if it exists
- If unavailable or open fails, show an info or error alert using the app's existing alert pattern

## Architecture

### New Pieces

- `RepoSettings` model
- `PullStrategy` enum if no existing reusable type is available
- `RepoSettingsStore` service
- `RepositorySettingsSheetView`

### Main Integration

Modify `MainWindowView` to:

- track whether the settings sheet is presented
- present `RepositorySettingsSheetView` from the toolbar button
- pass the current `repositoryURL`
- pass any repo-derived data needed for branch and remote choices
- route open-file and open-remote actions through existing helper behavior where possible

### Placement

Suggested file locations:

- `macgit/Models/RepoSettings.swift`
- `macgit/Services/RepoSettingsStore.swift`
- `macgit/Views/Common/RepositorySettingsSheetView.swift`

If the project later grows a broader settings surface, the view can move into a dedicated `Views/Settings` area without changing the underlying design.

## Error Handling

- Missing `.gitignore`: create the file, then open it
- Missing or inaccessible `.git/config`: show the existing alert UI
- Branch or remote loading failure: show empty picker data but keep manual input paths available
- External open failures: surface as an info or error alert rather than failing silently
- Invalid optional text values: normalize or clear them instead of hard-blocking save

## Testing

### Unit Tests

- `RepoSettingsStore` load/save behavior keyed by repository path
- default values for repositories with no saved settings
- encoding and decoding compatibility for `RepoSettings`

### Integration Tests

- `.gitignore` creation and open-path behavior when missing
- branch and remote option loading logic
- save flow from sheet state into `RepoSettingsStore`

### UI Tests

- clicking the `Settings` toolbar button presents the sheet
- top-tab navigation renders the expected sections
- save and cancel behaviors
- hybrid default pull branch input supports both picker and manual entry

## Defaults

Recommended initial defaults:

- `defaultRemoteName`: first available remote, otherwise `nil`
- `defaultPullBranch`: current branch if available, otherwise empty string
- `pullStrategy`: `merge`
- `autoFetchEnabled`: `false`
- `refreshOnAppActive`: `true`
- `confirmDetachedHeadCheckout`: `true`
- `confirmDestructiveStashActions`: `true`

These defaults preserve current app behavior as much as possible while adding repository-specific customization.

## Future Enhancements

- Push behavior defaults
- More granular fetch scheduling
- Per-repo external tool preferences
- Read-only display of resolved repo metadata
- Inline validation hints for unusual branch configurations
- A future bridge from repo settings into global preferences where appropriate

## Files To Create Or Modify

**New files:**

- `macgit/Models/RepoSettings.swift`
- `macgit/Services/RepoSettingsStore.swift`
- `macgit/Views/Common/RepositorySettingsSheetView.swift`

**Modified files:**

- `macgit/Views/MainWindow/MainWindowView.swift` - present the settings sheet from the toolbar
- related repository-loading or helper files as needed to provide branch and remote choices

## Decision Log

- Scope is **repo-specific only**
- Global preferences are intentionally deferred to a future separate feature
- Modal style is **top tabs**
- v1 shape is **balanced**, not minimal and not advanced
- `.gitignore` and `.git/config` use **Open in External Editor** behavior instead of inline editing
- `Default Pull Branch` uses a **hybrid** picker plus manual entry model
