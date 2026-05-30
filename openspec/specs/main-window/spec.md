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

### Requirement: Toolbar Git Action Buttons with Badges
The main window SHALL display functional Commit, Pull, Push, and Fetch buttons in the left toolbar, where Commit, Push, and Pull buttons display a numeric badge indicating pending operations.

#### Scenario: Commit badge shows total file changes
- **WHEN** the working directory of the open repository contains staged, unstaged, or untracked files
- **THEN** the Commit toolbar button displays a badge with the total count of those files
- **AND** if the count exceeds 99 the badge displays "99+"

#### Scenario: Push badge shows unpushed commits
- **WHEN** the current local branch is ahead of its upstream tracking branch
- **THEN** the Push toolbar button displays a badge with the ahead commit count
- **AND** if the count exceeds 99 the badge displays "99+"

#### Scenario: Pull badge shows unfetched remote commits
- **WHEN** the upstream tracking branch has commits not present on the current local branch
- **THEN** the Pull toolbar button displays a badge with the behind commit count
- **AND** if the count exceeds 99 the badge displays "99+"

#### Scenario: Fetch button has no badge
- **WHEN** the Fetch toolbar button is rendered
- **THEN** it does not display a numeric badge

#### Scenario: Toolbar button actions execute Git commands
- **WHEN** the user clicks the Commit toolbar button
- **THEN** the commit sheet opens as before
- **WHEN** the user clicks Push, Pull, or Fetch
- **THEN** the corresponding Git command is executed

#### Scenario: Error popup on toolbar action failure
- **WHEN** a toolbar Git action fails with a Git CLI error
- **THEN** a native alert popup appears showing the error message

