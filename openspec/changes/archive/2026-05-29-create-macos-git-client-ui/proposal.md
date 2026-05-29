# Change: Create macOS Git Client UI

## Why
Build a native macOS Git client using SwiftUI with a modern macOS 26-style UI (high border radius, native look). The app should allow users to open or clone Git repositories and provide a familiar two-panel interface inspired by native macOS design patterns.

## What Changes
- Add a repository picker/onboarding window that appears on every app launch
- Allow users to open an existing local Git repository (validated by `.git` directory presence) or clone a new repository from a remote URL
- Display recently opened repositories in the picker, sorted by most recently opened first
- Replace the default CoreData-based ContentView with a main two-panel window:
  - Left sidebar with workspace sections (File status, History, Search)
  - Right content panel that updates based on sidebar selection
- Style the UI with high border radius and native macOS 26 aesthetics (rounded corners, subtle shadows, Apple-style spacing)
- Remove default CoreData boilerplate (`Item`, `PersistenceController` preview data) not needed for the Git client

## Impact
- Affected specs:
  - `repo-picker` — new capability for onboarding / repository selection
  - `main-window` — new capability for the primary application interface
- Affected code:
  - `macgit/macgitApp.swift` — update scene and environment setup
  - `macgit/ContentView.swift` — replace default view with main window
  - `macgit/Persistence.swift` — clean up unused preview boilerplate
  - New files: `RepoPickerView.swift`, `MainWindowView.swift`, `SidebarView.swift`, `RecentRepositoriesStore.swift`

## Out of Scope
- Graph UI or branch visualization (to be implemented later)
- Full commit diff rendering with syntax highlighting
- Git operations beyond basic repository opening/cloning validation
