## MODIFIED Requirements

### Requirement: Toolbar Git Action Buttons with Badges
The main window SHALL display functional Commit, Pull, Push, and Fetch buttons in the left toolbar, where Commit, Push, and Pull buttons display a numeric badge indicating pending operations.

#### Scenario: Branch button opens branch management sheet
- **WHEN** the user clicks the Branch toolbar button
- **THEN** a sheet modal opens allowing the user to create or delete branches

#### Scenario: More menu branch action opens branch management sheet
- **WHEN** the window is narrow and the user selects Branch from the More menu
- **THEN** the same branch management sheet opens

## ADDED Requirements

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
