# main-window Specification

## Purpose
TBD - created by archiving change create-macos-git-client-ui. Update Purpose after archive.
## Requirements
### Requirement: Main Two-Panel Window
The system SHALL provide a main application window with a left sidebar and a right content panel after a repository is opened.

#### Scenario: Main window layout
- **WHEN** a valid repository is opened or cloned
- **THEN** the picker closes and a window with a left sidebar and right detail panel is displayed

### Requirement: Sidebar Navigation
The system SHALL provide a left sidebar with workspace navigation items.

#### Scenario: Sidebar items visible
- **WHEN** the main window is active
- **THEN** the sidebar contains at minimum the following sections and items:
  - **WORKSPACE**: File status, History, Search
  - Placeholder sections (collapsed or disabled) for Branches, Tags, Remotes, Stashes, Submodules, Subtrees

#### Scenario: Sidebar selection updates detail
- **WHEN** the user selects an item in the sidebar
- **THEN** the right panel updates to show the corresponding content view

### Requirement: macOS 26 Native Styling
The system SHALL apply macOS 26-style visual design across the main window.

#### Scenario: High border radius applied
- **WHEN** the main window and its components are rendered
- **THEN** container backgrounds, list rows, and buttons use a high corner radius (≥ 16 pt) consistent with macOS 26 design language

#### Scenario: Native materials and spacing
- **WHEN** the main window is displayed
- **THEN** backgrounds use appropriate materials (e.g., `.thinMaterial`) and spacing follows Apple Human Interface Guidelines

### Requirement: Detail Placeholder Views
The system SHALL display placeholder content in the right panel for each implemented sidebar item.

#### Scenario: File status placeholder
- **WHEN** the user selects "File status" in the sidebar
- **THEN** the right panel shows a placeholder indicating file status content will appear here

#### Scenario: History placeholder
- **WHEN** the user selects "History" in the sidebar
- **THEN** the right panel shows a placeholder indicating commit history content will appear here

#### Scenario: Search placeholder
- **WHEN** the user selects "Search" in the sidebar
- **THEN** the right panel shows a placeholder indicating search content will appear here

