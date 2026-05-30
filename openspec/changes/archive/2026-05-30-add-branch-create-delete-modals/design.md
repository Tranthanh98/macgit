## Context
The main window toolbar has a Branch button that currently does nothing. The user wants SourceTree-style Create and Delete branch modals accessible from that button. This touches both the UI layer (`Views/`) and the Git CLI service layer (`Services/GitStatusService.swift`).

## Goals / Non-Goals
- **Goals:**
  - Provide a single modal sheet with Create and Delete tabs for branch management.
  - Live preview of sanitized branch names from free-text input.
  - Support deleting both local and remote branches with confirmation.
- **Non-Goals:**
  - Branch renaming (not requested).
  - Full commit graph visualization inside the commit picker (a simple list/picker is sufficient).
  - Bulk branch operations beyond multi-select delete.

## Decisions
- **Single sheet with segmented control:** Rather than two separate sheets, use one `BranchSheetView` with a picker/tab to switch between New Branch and Delete Branches. This matches SourceTree’s unified branch dialog and reduces toolbar clutter.
- **Sanitization rules:** Convert to lowercase, replace spaces and non-alphanumeric (except `-`, `_`, `/`) with `-`, collapse consecutive separators, trim leading/trailing separators. This matches typical Git branch naming conventions while remaining permissive.
- **Commit picker for create:** For "Specified commit", present a simple list of recent commits (e.g., last 50 from `git log --oneline`) in a dropdown/picker rather than a full graph view. This keeps the implementation minimal.
- **Remote branch deletion:** When a remote branch is selected for deletion, execute `git push <remote> --delete <branch>`. The remote name is derived from the branch ref (e.g., `origin/feat/foo` → remote `origin`, branch `feat/foo`).

## Risks / Trade-offs
- **Risk:** Commit picker may be slow on huge repos.
  - *Mitigation:* Cap the log to 50 entries; add a search field if needed later.
- **Risk:** Force delete can cause data loss.
  - *Mitigation:* Always show a confirmation alert summarizing selected branches before executing deletion, regardless of force flag.

## Open Questions
- None — clarified with user.
