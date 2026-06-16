# macgit AGENTS.md

## Project: macgit (Commit+)
A macOS Git client built with SwiftUI.

## Recent Changes

### Menu Bar Actions Enable/Disable Logic (2026-06-16)
**Problem:** The Actions menu in the menu bar was always disabled because the `@FocusedValue` / `@FocusedBinding` mechanism in macOS SwiftUI doesn't reliably work with `NavigationSplitView`. The focus values set by `MainWindowView` were never picked up by the `CommandMenu` in `macgitApp.swift`.

**Solution:**
1. **Actions are handled via Notifications** — `macgitApp.swift` posts `Notification.Name.toolbarAction` (defined in `ToolbarAction.swift`) when a menu button is clicked. `MainWindowView` listens for this notification and calls `handleToolbarAction(_:)`.
2. **Enable/disable is based on `AppState.hasOpenRepository`** — The `Actions` menu buttons are disabled when `appState.hasOpenRepository == false` (i.e., when the `RepoPickerView` is shown). When a repository is open, all buttons are enabled.
3. **The actual guard logic (syncing, staged count, etc.) lives in `handleToolbarAction`** — This is the same function used by toolbar buttons, so the behavior is consistent.

**Files involved:**
- `macgit/App/ToolbarAction.swift` — Defines `ToolbarAction` enum, `ToolbarActionState` struct, and `Notification.Name.toolbarAction`
- `macgit/App/macgitApp.swift` — `CommandMenu("Actions")` posts notifications and uses `.disabled(!appState.hasOpenRepository)`
- `macgit/Views/MainWindow/MainWindowView.swift` — Listens for `.toolbarAction` notification and calls `handleToolbarAction`

**Note:** The old `@FocusedValue` / `@FocusedBinding` / `focusedSceneValue` approach was abandoned because it doesn't work reliably in this SwiftUI + NavigationSplitView setup on macOS. The notification-based approach is robust and explicit.
