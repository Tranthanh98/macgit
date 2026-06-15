# Quick Search Modal Design

## Overview

A **Spotlight-style search modal** for macgit that allows users to quickly search across commits, files, branches, and tags from anywhere in the app using the `Cmd+Shift+F` shortcut.

## Goals

- Provide instant, keyboard-driven search across all git repository data
- Keep users in flow without navigating away from their current context
- Show rich, grouped results with clear visual hierarchy
- Support keyboard navigation for power users

## Non-Goals

- Full-text search inside file contents (out of scope for initial version)
- Fuzzy search with typos (simple substring matching for v1)
- Search across multiple repositories simultaneously

## Architecture

### Components

1. **`SearchModalView`** — Main SwiftUI view presented as a modal overlay
2. **`SearchResult`** — Data model representing a single search result
3. **`SearchResultType`** — Enum for result categories (commit, file, branch, tag)
4. **`SearchAction`** — Enum for actions triggered by selecting a result
5. **`GitStatusService+Search`** — Extension providing `search(query: String, in: URL)` method
6. **`SearchCoordinator`** — Observable object managing search state, results, and keyboard navigation

### Data Flow

```
User types query
    ↓
SearchCoordinator.debounce(300ms)
    ↓
GitStatusService.search(query, repositoryURL)
    ↓
Parallel git subprocesses:
    - git log --all --grep=<query> -n 20
    - git ls-files | grep -i <query>
    - git branch -a | grep -i <query>
    - git tag -l *<query>*
    ↓
Merge & sort results by type
    ↓
SearchCoordinator.results = [SearchResult]
    ↓
SwiftUI re-renders SearchModalView
```

## UI Design

### Modal Appearance

- **Position:** Centered horizontally, top 20% of screen vertically
- **Size:** 640px wide, height adapts to results (max 500px)
- **Background:** Semi-transparent white (`rgba(255,255,255,0.95)`) with backdrop blur
- **Shadow:** `0 20px 60px rgba(0,0,0,0.2)`
- **Border:** `1px solid rgba(0,0,0,0.08)`
- **Backdrop:** Dimmed main window (`rgba(0,0,0,0.15)` overlay)

### Search Bar

- Large input field with magnifying glass icon
- Placeholder: "Search commits, files, branches..."
- Shows shortcut hints: `⌘⏎` (jump to commit), `⌘⇧F` (trigger shortcut)
- Clear button (×) appears when text is present
- 300ms debounce before executing search

### Results Layout

Results grouped by type with section headers:

```
┌─────────────────────────────────────────┐
│  🔍  Search commits, files, branches... │
├─────────────────────────────────────────┤
│  COMMITS                               │
│  📝 Add auth middleware                 │  ← Selected (highlighted)
│     abc1234 • Thanh • 2h ago           │
│  📝 Fix login redirect                  │
│     def5678 • Thanh • 5h ago           │
├─────────────────────────────────────────┤
│  FILES                                 │
│  📄 AuthMiddleware.swift               │
│     macgit/Services/...                │
├─────────────────────────────────────────┤
│  BRANCHES                              │
│  🌿 feature/auth                       │
│     origin/feature/auth                │
├─────────────────────────────────────────┤
│  TAGS                                  │
│  🏷 v1.2.0                             │
│     abc1234                            │
├─────────────────────────────────────────┤
│  ↑↓ Navigate • ↵ Select • ⌘⏎ Jump     │
└─────────────────────────────────────────┘
```

### Result Row Design

- **Icon:** Type-specific SF Symbol (📝 commit, 📄 file, 🌿 branch, 🏷 tag)
- **Title:** Primary text (commit message, file name, branch name, tag name)
- **Subtitle:** Secondary info (hash/author/time, file path, remote tracking, commit hash)
- **Badge:** Optional status (e.g., "Modified", "Staged", "Remote")
- **Selection:** Blue background with white text when selected

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate through results |
| `↵` | Execute primary action for selected result |
| `⌘↵` | For commits: jump to commit in History view |
| `Esc` | Close modal |
| `Cmd+Shift+F` | Open modal from anywhere |

## Search Implementation

### Git Commands

**Commits:**
```bash
git log --all --grep="<query>" -n 20 --format="%H|%s|%an|%ai"
```
Also search by hash prefix:
```bash
git log --all --oneline --format="%H|%s|%an|%ai" | grep -i "<query>" | head -20
```

**Files:**
```bash
git ls-files | grep -i "<query>"
```

**Branches:**
```bash
git branch -a | grep -i "<query>"
```

**Tags:**
```bash
git tag -l "*<query>*"
```

### Result Merging

Results are fetched in parallel using `withTaskGroup` and merged maintaining section order:
1. Commits (most relevant)
2. Files
3. Branches
4. Tags

Each section limited to first 20 results.

### Empty State

When no results found:
```
┌─────────────────────────────────────────┐
│  🔍  "abcxyz"                          │
├─────────────────────────────────────────┤
│                                         │
│     No results found                    │
│     Try a different search term         │
│                                         │
└─────────────────────────────────────────┘
```

## Integration

### Presentation

The modal is triggered from `MainWindowView` via a global keyboard shortcut (`Cmd+Shift+F`). It is presented as an overlay using a `ZStack` with a full-screen dimmed background.

### Dismissal

- `Esc` key
- Click outside the modal
- Executing an action (optional — could keep modal open for multi-select)

### Navigation to Existing Views

When a result is selected:
- **Commit:** Navigate to History view with the commit selected
- **File:** Navigate to File Status view with the file highlighted
- **Branch:** Navigate to History view filtered to that branch
- **Tag:** Navigate to History view at that tag

## Performance Considerations

- Debounce: 300ms after typing stops before executing search
- Timeout: 5 seconds per search query
- Parallel execution: All search types run concurrently
- Caching: Not needed for v1 (queries are fast enough)
- Lazy loading: Not needed (max 80 results total)

## Error Handling

- Search errors show inline in the modal footer
- Git errors are caught and logged, but don't block other search types
- Network timeout shows "Search timed out" message
- Empty repository shows appropriate empty state

## Testing

### Unit Tests
- `SearchResult` model serialization
- `SearchCoordinator` state management
- Keyboard navigation logic

### Integration Tests
- `GitStatusService.search()` with various queries
- Git command output parsing
- Result merging and sorting

### UI Tests
- Modal presentation/dismissal
- Keyboard shortcut triggering
- Result selection and navigation
- Empty state rendering

## Future Enhancements

- Full-text file content search (`git log -S`)
- Fuzzy matching with scoring
- Recent searches history
- Favorite/pinned results
- Search across multiple repositories
- Advanced filters (author, date range, file type)

## Files to Create/Modify

**New files:**
- `macgit/Views/Search/SearchModalView.swift`
- `macgit/Views/Search/SearchResultRow.swift`
- `macgit/Models/SearchResult.swift`
- `macgit/ViewModels/SearchCoordinator.swift`
- `macgit/Services/GitStatusService+Search.swift`

**Modified files:**
- `macgit/Views/MainWindow/MainWindowView.swift` — Add modal overlay and keyboard shortcut
- `macgit/Views/Search/SearchView.swift` — Update or remove placeholder
- `macgit/Views/MainWindow/SidebarView.swift` — Search sidebar item can trigger modal

## Open Questions

1. Should the search modal support multi-select (e.g., select multiple files)?
2. Should we show file content previews in search results?
3. Should the search sidebar item in the sidebar remain, or should search only be accessible via shortcut?
4. Should we cache recent searches for quick re-access?

## Decision Log

- **Modal vs. Sidebar:** Chose modal (Spotlight-style) for speed and keyboard accessibility
- **Layout style:** Centered floating panel (Option A) — best for keyboard-driven UX
- **Result types:** All four (commits, files, branches, tags) — comprehensive search
- **Backend:** Parallel git subprocess calls via `GitStatusService` — consistent with existing patterns
- **Debounce:** 300ms — balance between responsiveness and performance
- **Max results:** 20 per section — keeps modal performant and readable
