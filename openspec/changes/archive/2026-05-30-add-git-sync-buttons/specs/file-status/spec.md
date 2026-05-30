## ADDED Requirements

### Requirement: Background Remote Sync for Badge Counts
The system SHALL periodically refresh remote-tracking branch information so the Pull and Push toolbar badges remain accurate without requiring manual Fetch.

#### Scenario: Periodic background fetch
- **WHEN** a repository is open in the main window
- **THEN** a background job runs `git fetch` at a 60-second interval
- **AND** after each fetch the system recalculates ahead/behind counts
- **AND** the Push and Pull toolbar badge counts update accordingly

#### Scenario: Background fetch failure is silent
- **WHEN** a background fetch fails (e.g. network unreachable or uncached SSH credentials)
- **THEN** the failure does not trigger an alert popup or interrupt the user
- **AND** the next scheduled fetch attempt continues normally

### Requirement: Working Directory Conflict Detection
The system SHALL detect and surface the presence of conflicted files in the working directory before allowing destructive or sync actions.

#### Scenario: Conflicts visible in status
- **WHEN** the working directory contains conflicted files
- **THEN** those files appear in the File status view under the appropriate section with a conflict indicator

#### Scenario: Pre-action conflict check
- **WHEN** any sync action (Push, Pull, Commit) is about to execute
- **AND** the current `GitStatus` contains files with `.conflict` status
- **THEN** the action is aborted and a conflict notice popup is presented
