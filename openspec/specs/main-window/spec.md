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
The main window SHALL display functional Commit, Pull, Push, Fetch, Branch, and Merge buttons in the left toolbar. Commit, Push, and Pull buttons display a numeric badge indicating pending operations.

#### Scenario: Merge button opens merge sheet
- **WHEN** the user clicks the Merge toolbar button
- **THEN** a sheet modal opens allowing the user to select a source branch and merge options

#### Scenario: Merge button disabled during sync
- **WHEN** any sync operation (Commit, Pull, Push, Fetch, or Merge) is in progress
- **THEN** the Merge button is disabled

### Requirement: Create New Branch Modal
The system SHALL provide a modal for creating a new branch from the main window toolbar.

#### Scenario: Display current branch
- **WHEN** the create branch tab is active
- **THEN** the current branch name is displayed as a read-only field

#### Scenario: Free-text branch name with live preview
- **WHEN** the user types any text into the new branch name field
- **THEN** a live preview shows the sanitized branch name that will be created

#### Scenario: Create from working copy parent
- **WHEN** the user selects "Working copy parent" as the commit source
- **THEN** the new branch is created from the current HEAD

#### Scenario: Create from specified commit
- **WHEN** the user selects "Specified commit" and picks a commit
- **THEN** the new branch is created from that commit

#### Scenario: Checkout after creation
- **WHEN** the user checks "Checkout new branch" and clicks Create Branch
- **THEN** the system creates the branch and switches to it

#### Scenario: Create without checkout
- **WHEN** the user unchecks "Checkout new branch" and clicks Create Branch
- **THEN** the system creates the branch but remains on the current branch

### Requirement: Delete Branches Modal
The system SHALL provide a modal for deleting local and remote branches from the main window toolbar.

#### Scenario: List local and remote branches
- **WHEN** the delete branches tab is active
- **THEN** a table displays all local and remote branches with a Type column

#### Scenario: Select branches to delete
- **WHEN** the user checks one or more branches in the list
- **THEN** those branches are marked for deletion

#### Scenario: Force delete option
- **WHEN** the user checks "Force delete regardless of merge status"
- **THEN** the deletion will use force flag even if branches are not fully merged

#### Scenario: Confirm before deletion
- **WHEN** the user clicks "Delete Branches"
- **THEN** a confirmation alert appears listing the selected branches before executing deletion

#### Scenario: Delete local branches
- **WHEN** the user confirms deletion of selected local branches
- **THEN** the system runs `git branch -d` (or `-D` if force) for each selected local branch

#### Scenario: Delete remote branches
- **WHEN** the user confirms deletion of selected remote branches
- **THEN** the system runs `git push <remote> --delete <branch>` for each selected remote branch

### Requirement: Toolbar Merge Button Sheet
The system SHALL provide a modal dialog when the user clicks the Merge toolbar button, allowing selection of a source branch and merge options before executing the command.

#### Scenario: Merge dialog opens
- **WHEN** the user clicks the Merge toolbar button
- **THEN** a modal sheet appears showing:
  - A "Source branch" picker populated with local and remote branches (excluding the current branch)
  - The current local branch name displayed as read-only under "Merge into"
  - An Options section with toggles:
    - No fast-forward (default OFF)
    - Squash (default OFF)
  - A "Commit message" field auto-filled with `Merge branch '<source>' into <target>` and editable
  - Cancel and OK buttons

#### Scenario: Merge executes with selected options
- **WHEN** the user clicks OK in the Merge dialog
- **THEN** the system executes `git merge` with the selected branch and options applied via appropriate flags (`--no-ff`, `--squash`)
- **AND** the dialog closes

#### Scenario: Merge from toolbar or More menu
- **WHEN** the window is wide and the user clicks the Merge toolbar button
- **THEN** the Merge sheet opens
- **WHEN** the window is narrow and the user selects Merge from the More menu
- **THEN** the same Merge sheet opens

#### Scenario: Cancel Merge dialog
- **WHEN** the user clicks Cancel in the Merge dialog
- **THEN** the dialog closes and no Git command is executed

