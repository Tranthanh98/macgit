# Change: Add Branch Create and Delete Modals

## Why
The Branch button in the main window toolbar is currently a no-op (`action: {}`). Users need a way to create new branches and delete existing branches directly from the toolbar, matching the workflow in SourceTree and other Git GUIs.

## What Changes
- Add a modal sheet for **creating** a new branch (referencing SourceTree UI):
  - Display current branch
  - Allow free-text branch name input with live preview of the sanitized name
  - Support two commit sources: "Working copy parent" (default) and "Specified commit" with a commit picker
  - "Checkout new branch" toggle (default on)
  - Execute `git branch` / `git checkout -b` via `GitStatusService`
- Add a modal sheet for **deleting** branches (referencing SourceTree UI):
  - List all local and remote branches in a selectable table
  - Show branch type (Local / Remote)
  - "Force delete regardless of merge status" toggle
  - Confirmation alert before executing deletion
  - Execute `git branch -d/-D` and `git push --delete` via `GitStatusService`
- Wire the toolbar Branch button (and the "More" menu Branch item) to open the create-branch sheet.
- Provide a segmented control or tab switcher inside the sheet to toggle between Create and Delete modes.

## Impact
- Affected specs: `main-window`
- Affected code:
  - `macgit/Views/MainWindow/MainWindowView.swift` — add `@State` flags and sheet presentation
  - `macgit/Views/Common/BranchSheetView.swift` — new view (create + delete UI)
  - `macgit/Services/GitStatusService.swift` — add `createBranch`, `deleteBranch`, `deleteRemoteBranch` helpers
