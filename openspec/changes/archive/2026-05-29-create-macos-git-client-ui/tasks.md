## 1. Project Setup & Cleanup
- [x] 1.1 Remove unused CoreData `Item` entity and preview boilerplate from `Persistence.swift`
- [x] 1.2 Update `macgitApp.swift` to remove CoreData environment injection (keep `PersistenceController` for future recent-repos storage if needed)
- [x] 1.3 Verify project builds after cleanup

## 2. Repository Picker (Onboarding)
- [x] 2.1 Create `RecentRepositoriesStore` to read/write recent repo URLs with timestamps (using `UserDefaults` or lightweight file storage)
- [x] 2.2 Create `RepoPickerView` with:
  - "Open Existing Repository" button triggering `NSOpenPanel` (folder picker, validate `.git` exists)
  - "Clone New Repository" button with URL input + destination folder picker
  - List of recent repositories sorted by latest opened first
  - macOS 26 high border-radius styling on buttons and list rows
- [x] 2.3 Wire picker into `macgitApp.swift` as the initial window content
- [x] 2.4 Handle validation errors (missing `.git`, invalid clone URL) with native alerts

## 3. Main Window Layout
- [x] 3.1 Create `SidebarView` with workspace sections:
  - File status
  - History
  - Search
  - Collapsible/disabled placeholders for Branches, Tags, Remotes, Stashes, Submodules, Subtrees (out of scope)
- [x] 3.2 Create `MainWindowView` with `NavigationSplitView` (or `HSplitView` with `List` + `Detail`) for left sidebar + right panel
- [x] 3.3 Create placeholder detail views for each sidebar selection:
  - `FileStatusView` — placeholder message
  - `HistoryView` — placeholder message
  - `SearchView` — placeholder message
- [x] 3.4 Apply macOS 26 style: high `.cornerRadius`, `.background` materials, padding/spacing consistent with Apple design
- [x] 3.5 Transition from `RepoPickerView` to `MainWindowView` after successful repo open/clone

## 4. Styling & Polish
- [x] 4.1 Audit all custom UI components for consistent high border radius (`16`–`20` pt on macOS 26)
- [x] 4.2 Use `.ultraThinMaterial` / `.thinMaterial` backgrounds where appropriate
- [x] 4.3 Ensure sidebar selection states match native macOS accent colors
- [x] 4.4 Add toolbar items (e.g., path label, refresh) in main window

## 5. Validation
- [x] 5.1 Build project successfully in Xcode
- [x] 5.2 Test opening a valid Git repository
- [x] 5.3 Test rejecting a non-Git folder
- [x] 5.4 Test recent repositories list ordering
- [x] 5.5 Test cloning flow (UI only; actual clone can delegate to `git` CLI or `Process`)
