# git-remote-sync Specification

## Purpose
TBD - created by archiving change add-git-sync-buttons. Update Purpose after archive.
## Requirements
### Requirement: Remote Synchronization Operations
The system SHALL support Push, Pull, Fetch, and Merge operations against the repository via Git CLI, and provide ahead/behind commit counts for the current branch.

#### Scenario: Merge badge not shown
- **WHEN** the system displays toolbar buttons
- **THEN** the Merge button does not display a numeric badge

### Requirement: Conflict Detection and Popup Notice
The system SHALL detect merge conflicts in the working directory before executing Push, Pull, Commit, or Merge, and display a popup notice. It SHALL also detect conflicts that arise during a Pull or Merge operation.

#### Scenario: Existing conflicts block Merge
- **WHEN** the user clicks the Merge toolbar button
- **AND** the working directory contains files with a conflict status
- **THEN** a native alert popup warns the user that conflicts must be resolved first
- **AND** the Merge sheet does not open

#### Scenario: Conflicts arising during Merge
- **WHEN** the user triggers Merge
- **AND** the merge results in conflicts
- **THEN** a native alert popup notifies the user that merge conflicts occurred during Merge
- **AND** the File status view refreshes to show the new conflicted files

### Requirement: Pull Modal Dialog
The system SHALL display a modal dialog when the user clicks the Pull toolbar button, allowing selection of remote repository, remote branch, and pull options before executing the command.

#### Scenario: Pull dialog opens
- **WHEN** the user clicks the Pull toolbar button
- **THEN** a modal sheet appears showing:
  - A "Pull from repository" picker populated with configured remotes
  - A "Remote branch to pull" picker populated with remote-tracking branches and a Refresh button
  - The current local branch name displayed under "Pull into local branch"
  - An Options section with toggles:
    - Commit merged changes immediately (default ON)
    - Include messages from commits being merged in merge commit (default ON)
    - Create new commit even if fast-forward merge (default OFF)
    - Rebase instead of merge (default OFF)
  - Cancel and OK buttons

#### Scenario: Pull executes with selected options
- **WHEN** the user clicks OK in the Pull dialog
- **THEN** the system executes `git pull <remote> <branch>` with the selected options applied via appropriate flags (`--no-commit`, `--no-log`, `--no-ff`, `--rebase`)
- **AND** the dialog closes

#### Scenario: Pull with no new changes
- **WHEN** the Pull command completes successfully
- **AND** there were no new changes to merge
- **THEN** a native alert popup appears with the message "Already up to date."

#### Scenario: Pull with new changes
- **WHEN** the Pull command completes successfully
- **AND** new commits were merged
- **THEN** a native alert popup appears with the message "Pull completed successfully."

#### Scenario: Cancel Pull dialog
- **WHEN** the user clicks Cancel in the Pull dialog
- **THEN** the dialog closes and no Git command is executed

### Requirement: Fetch Empty Notification
The system SHALL display a brief notification when Fetch completes successfully but no new remote changes were retrieved.

#### Scenario: Fetch with no new changes
- **WHEN** the user triggers Fetch
- **AND** `git fetch` completes successfully
- **AND** the number of commits behind upstream did not increase
- **THEN** a native alert popup appears with the message "No new changes on remote."

### Requirement: Push Modal Dialog
The system SHALL display a modal dialog when the user clicks the Push toolbar button, allowing selection of remote repository, branches to push, and options before executing the command.

#### Scenario: Push dialog opens
- **WHEN** the user clicks the Push toolbar button
- **THEN** a modal sheet appears showing:
  - A "Push to repository" picker populated with configured remotes
  - A "Branches to push" list showing local branches with:
    - A checkbox to select the branch for pushing
    - The local branch name
    - The mapped remote branch name (if tracked)
    - A "Track" button to set upstream for untracked branches
  - A "Select All" checkbox
  - A "Push all tags" toggle
  - Cancel and OK buttons

#### Scenario: Push executes with selected branches
- **WHEN** the user clicks OK in the Push dialog
- **AND** at least one branch is selected
- **THEN** the system executes `git push <remote> <branch>` for each selected branch
- **AND** if "Push all tags" is enabled, also executes `git push --tags`
- **AND** the dialog closes

#### Scenario: Push with nothing to push
- **WHEN** the Push command completes successfully
- **AND** there were no new commits to push
- **THEN** a native alert popup appears with the message "Everything up-to-date."

#### Scenario: Push with new commits
- **WHEN** the Push command completes successfully
- **AND** new commits were pushed
- **THEN** a native alert popup appears with the message "Push completed successfully."

#### Scenario: Cancel Push dialog
- **WHEN** the user clicks Cancel in the Push dialog
- **THEN** the dialog closes and no Git command is executed

### Requirement: Branch Merge Operation
The system SHALL support merging a selected source branch into the current branch via Git CLI, and display success or conflict notifications upon completion.

#### Scenario: Fast-forward merge succeeds
- **WHEN** the user triggers Merge with a source branch that is ahead of the current branch
- **AND** fast-forward is possible
- **THEN** the system executes `git merge <branch>`
- **AND** upon success a native alert popup appears with the message "Merge completed successfully."
- **AND** the File status view and badge counts refresh

#### Scenario: No-fast-forward merge creates merge commit
- **WHEN** the user triggers Merge with "No fast-forward" enabled
- **THEN** the system executes `git merge --no-ff <branch>`
- **AND** upon success a native alert popup appears with the message "Merge completed successfully."
- **AND** the File status view and badge counts refresh

#### Scenario: Squash merge stages changes
- **WHEN** the user triggers Merge with "Squash" enabled
- **THEN** the system executes `git merge --squash <branch>`
- **AND** the changes are staged in the working directory for a subsequent commit
- **AND** a native alert popup appears with the message "Squash merge completed. Changes are staged."
- **AND** the File status view and badge counts refresh

#### Scenario: Merge with no changes
- **WHEN** the Merge command completes successfully
- **AND** there were no new changes to merge
- **THEN** a native alert popup appears with the message "Already up to date."

#### Scenario: Merge resulting in conflicts
- **WHEN** the user triggers Merge
- **AND** the merge results in conflicts
- **THEN** a native alert popup notifies the user that merge conflicts occurred during Merge
- **AND** the File status view refreshes to show the new conflicted files

