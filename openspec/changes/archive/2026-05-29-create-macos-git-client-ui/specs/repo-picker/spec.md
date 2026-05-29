## ADDED Requirements

### Requirement: Repository Picker Window
The system SHALL display a repository picker window on every app launch.

#### Scenario: Picker displayed on launch
- **WHEN** the application finishes launching
- **THEN** a modal or primary window appears prompting the user to open or clone a repository

### Requirement: Open Existing Repository
The system SHALL allow the user to select a local folder and validate that it contains a `.git` directory.

#### Scenario: Valid Git repository selected
- **WHEN** the user taps "Open Existing Repository" and selects a folder containing a `.git` subdirectory
- **THEN** the folder is accepted, added to recent repositories, and the main window opens for that repository

#### Scenario: Invalid folder selected
- **WHEN** the user selects a folder that does not contain a `.git` subdirectory
- **THEN** the system shows a native alert indicating the folder is not a valid Git repository and remains on the picker

### Requirement: Clone New Repository
The system SHALL provide UI to clone a new repository from a remote URL into a chosen local directory.

#### Scenario: Clone initiated
- **WHEN** the user provides a remote URL and selects a destination folder
- **THEN** the system validates inputs and proceeds to clone (UI acceptance; actual clone execution may be deferred)

### Requirement: Recent Repositories List
The system SHALL display recently opened repositories sorted by most recently opened first.

#### Scenario: Recent repos shown
- **WHEN** the picker window is visible
- **THEN** a list of recent repositories appears, ordered by the time they were last opened, with the most recent at the top

#### Scenario: Recent repo re-opened
- **WHEN** the user selects a recent repository from the list
- **THEN** the main window opens for that repository and its timestamp is updated to now
