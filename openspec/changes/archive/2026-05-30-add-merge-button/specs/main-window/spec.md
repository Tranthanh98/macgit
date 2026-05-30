## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Toolbar Git Action Buttons with Badges
The main window SHALL display functional Commit, Pull, Push, Fetch, Branch, and Merge buttons in the left toolbar. Commit, Push, and Pull buttons display a numeric badge indicating pending operations.

#### Scenario: Merge button opens merge sheet
- **WHEN** the user clicks the Merge toolbar button
- **THEN** a sheet modal opens allowing the user to select a source branch and merge options

#### Scenario: Merge button disabled during sync
- **WHEN** any sync operation (Commit, Pull, Push, Fetch, or Merge) is in progress
- **THEN** the Merge button is disabled
