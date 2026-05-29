# file-status Specification

## Purpose
TBD - created by archiving change implement-file-status-feature. Update Purpose after archive.
## Requirements
### Requirement: Working Directory Status Display
The system SHALL display the working-directory status of the currently opened repository in a two-panel layout: a file list on the left and a diff detail view on the right.

#### Scenario: Two-panel layout shown
- **WHEN** the user opens a valid Git repository and navigates to the File status sidebar item
- **THEN** the view is split into two panels:
  - Left panel lists files grouped into **Staged** (top) and **Changed** (bottom) sections
  - Right panel shows the diff of the currently selected file

#### Scenario: File selection
- **WHEN** the user clicks a file in the left panel
- **THEN** the file becomes selected and the right panel updates to show its diff

### Requirement: Stage and Unstage Actions
The system SHALL allow the user to stage unstaged files and unstage staged files directly from the File status view.

#### Scenario: Stage an unstaged file
- **WHEN** the user selects an unstaged file and triggers the "Stage" action
- **THEN** the file moves from the Unstaged section to the Staged section and `git add <path>` is executed

#### Scenario: Unstage a staged file
- **WHEN** the user selects a staged file and triggers the "Unstage" action
- **THEN** the file moves from the Staged section to the Unstaged section and `git reset HEAD -- <path>` is executed

### Requirement: Discard Changes
The system SHALL allow the user to discard changes in an unstaged file, after presenting a confirmation alert.

#### Scenario: Discard with confirmation
- **WHEN** the user triggers the "Discard" action on an unstaged modified or deleted file
- **THEN** a native confirmation alert appears warning that the action is irreversible
- **AND** only upon confirmation does the system execute `git checkout -- <path>` and remove the file from the list

### Requirement: Commit from Toolbar
The system SHALL provide a "Commit" action in the main toolbar that opens a commit sheet for composing a message and confirming the commit.

#### Scenario: Commit staged changes
- **WHEN** the user clicks the Commit toolbar button
- **THEN** a sheet appears with a text field for the commit message and a "Commit" button
- **AND** upon confirmation, the system executes `git commit -m "<message>"` for the staged files
- **AND** the File status view refreshes to reflect the committed state

### Requirement: Checkbox Stage/Unstage
The system SHALL allow the user to stage and unstage files by toggling a checkbox next to each file in the file list.

#### Scenario: Stage via checkbox
- **WHEN** the user checks the checkbox on an unstaged file
- **THEN** the file is staged via `git add <path>` and moves to the Staged section

#### Scenario: Unstage via checkbox
- **WHEN** the user unchecks the checkbox on a staged file
- **THEN** the file is unstaged via `git reset HEAD -- <path>` and moves to the Changed section

### Requirement: Diff Viewer
The system SHALL display a unified diff for the selected file, with added lines shown in green, removed lines in red, and context lines in neutral.

#### Scenario: Show unstaged diff
- **WHEN** the user selects an unstaged or untracked file
- **THEN** the right panel shows the diff between the working tree and the index/HEAD

#### Scenario: Show staged diff
- **WHEN** the user selects a staged file
- **THEN** the right panel shows the cached diff (index vs HEAD)

#### Scenario: Empty diff state
- **WHEN** no file is selected or the file has no diff content
- **THEN** the right panel shows an appropriate empty state message

