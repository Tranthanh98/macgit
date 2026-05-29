## Context
The existing macOS Git client (`macgit`) is a SwiftUI app with a `NavigationSplitView` sidebar and placeholder detail views. The goal is to replace the File status placeholder with a working implementation that reads the repository state and allows common Git actions.

## Goals / Non-Goals
- **Goals:**
  - Display working-directory status grouped by Staged / Unstaged / Untracked
  - Allow stage, unstage, discard, and commit actions
  - Follow the existing macOS 26 visual style
- **Non-Goals:**
  - Full libgit2 integration (unless already present)
  - Diff viewing / hunk-level staging
  - Branching, merging, or other Git operations beyond commit
  - External file watchers for live filesystem updates (refresh on appear/action is sufficient)

## Decisions
- **Git interaction approach:** Use `Process` to invoke the system `git` binary with porcelain flags. This avoids adding a new dependency and is sufficient for a simple status/action feature.
  - *Alternatives considered:* libgit2/SwiftGit — heavier dependency, not justified for simple porcelain parsing.
- **Data model:** `StatusFile` struct with a `GitStatus` enum (modified, staged, untracked, deleted, renamed). Parsed from `git status --porcelain` lines.
- **UI grouping:** Three `Section`s inside a `List`, using standard SwiftUI `List` with `.listStyle(.insetGrouped)` or similar to match macOS 26 rounded style.
- **Error handling:** Git command failures bubble up as `Error` and are shown in a native `Alert` in `FileStatusView`.
- **Refresh strategy:** Re-fetch status on `onAppear` and after every mutating action (stage/unstage/discard/commit).

## Risks / Trade-offs
- **Risk:** `git` binary may not be in PATH for all users → *Mitigation:* attempt `/usr/bin/git` fallback and surface a clear error if Git is not found.
- **Risk:** Large repositories may have slow `git status` → *Mitigation:* run status on a background thread (`Task` / `DispatchQueue`); acceptable for MVP.

## Migration Plan
No migration needed — this is additive. The existing placeholder view is replaced in-place.

## Open Questions
- Should we support multi-select stage/unstage, or single-file only for the first iteration? (Decision: single-file for MVP.)
