## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: Remote Synchronization Operations
The system SHALL support Push, Pull, Fetch, and Merge operations against the repository via Git CLI, and provide ahead/behind commit counts for the current branch.

#### Scenario: Merge badge not shown
- **WHEN** the system displays toolbar buttons
- **THEN** the Merge button does not display a numeric badge
