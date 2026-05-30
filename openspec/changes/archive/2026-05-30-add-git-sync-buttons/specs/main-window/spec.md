## ADDED Requirements

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
