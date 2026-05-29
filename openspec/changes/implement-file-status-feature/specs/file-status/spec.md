## ADDED Requirements

### Requirement: Working Directory Status Display
The system SHALL display the working-directory status of the currently opened repository, grouped into "Staged", "Unstaged", and "Untracked" sections.

#### Scenario: Status parsed on repository open
- **WHEN** the user opens a valid Git repository and navigates to the File status sidebar item
- **THEN** the File status view lists all changed files, grouped into:
  - **Staged** — files in the index but not yet committed
  - **Unstaged** — modified or deleted files not in the index
  - **Untracked** — new files not tracked by Git

#### Scenario: Visual distinction per section
- **WHEN** the file list is rendered
- **THEN** each section uses a distinct color consistent with Git conventions (staged = green, unstaged = red, untracked = grey)

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
