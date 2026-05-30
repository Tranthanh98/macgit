## ADDED Requirements

### Requirement: Remote Synchronization Operations
The system SHALL support Push, Pull, and Fetch operations against the remote repository via Git CLI, and provide ahead/behind commit counts for the current branch.

#### Scenario: Push sends local commits to remote
- **WHEN** the user triggers Push
- **THEN** the system executes `git push` in the open repository
- **AND** upon success the File status view and badge counts refresh

#### Scenario: Pull merges remote commits into local branch
- **WHEN** the user triggers Pull
- **THEN** the system executes `git pull` in the open repository
- **AND** upon success the File status view and badge counts refresh

#### Scenario: Fetch updates remote-tracking branches
- **WHEN** the user triggers Fetch
- **THEN** the system executes `git fetch` in the open repository
- **AND** upon success the Pull and Push badge counts are immediately refreshed

#### Scenario: Ahead count for Push badge
- **WHEN** the system calculates ahead/behind counts
- **THEN** it runs `git rev-list --count @{upstream}..HEAD` to determine how many local commits are ahead of the upstream

#### Scenario: Behind count for Pull badge
- **WHEN** the system calculates ahead/behind counts
- **THEN** it runs `git rev-list --count HEAD..@{upstream}` to determine how many upstream commits are behind the local branch

### Requirement: Conflict Detection and Popup Notice
The system SHALL detect merge conflicts in the working directory before executing Push, Pull, or Commit, and display a popup notice. It SHALL also detect conflicts that arise during a Pull operation.

#### Scenario: Existing conflicts block Push and Pull
- **WHEN** the user clicks Push or Pull
- **AND** the working directory contains files with a conflict status
- **THEN** a native alert popup warns the user that conflicts must be resolved first
- **AND** the Git command is not executed

#### Scenario: Conflicts arising during Pull
- **WHEN** the user triggers Pull
- **AND** the merge results in conflicts
- **THEN** a native alert popup notifies the user that merge conflicts occurred during Pull
- **AND** the File status view refreshes to show the new conflicted files

#### Scenario: Existing conflicts shown before Commit
- **WHEN** the user opens the Commit sheet from the toolbar
- **AND** the working directory contains conflicted files
- **THEN** a native alert popup warns the user about unresolved conflicts
