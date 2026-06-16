# Conflict Merge Tool Redesign

**Date:** 2026-06-16
**Status:** Approved

## Problem

The current `ConflictMergeToolView` is a basic modal sheet with:
- Plain text panes for "Current" and "Incoming" (no syntax highlighting, no line numbers)
- A generic `TextEditor` for the result
- "Use Current / Use Incoming / Use Both" buttons that are detached from the actual conflict blocks
- A "Resolved File Preview" section that duplicates information
- No way to see or navigate between multiple conflict files in the repository

## Goals

1. Make the conflict resolver feel like a code workspace, not a form.
2. Add syntax highlighting and line numbers to all code panes.
3. Allow selecting conflict resolutions inline via checkboxes per conflict block.
4. Enable navigation across all conflict files in the repository.
5. Remove redundant elements (Resolved File Preview, detached action buttons).

## Approach

**Approach A: Large Sheet with Sidebar** (selected)

Keep the existing `.sheet` in `FileStatusView` but expand it to a larger frame. Inside the sheet, use a 3-column layout:
- Left sidebar: all conflict files in the repository
- Main area: vertically scrollable view of all conflict blocks in the selected file
- Top header: file name, remaining conflict count, Prev/Next navigation, Complete/Merge button

### Why not B or C?
- **B (dedicated window)** introduces window management complexity that is not needed for this focused task.
- **C (inline in FileStatusView)** would lose the dedicated workspace feel and make it hard to show a conflict file sidebar.

## Design

### 1. Layout & Structure

- **Frame:** `minWidth: 1200, idealWidth: 1400, minHeight: 800, idealHeight: 900`
- **Top Header Bar** (fixed, ~56px):
  - Left: Title "Resolve Conflicts" + current file name (secondary, truncated)
  - Center: "Conflict X of Y remaining" + `Prev` / `Next` buttons
  - Right: `Complete / Merge` button
- **Left Sidebar** (~220px):
  - List of all conflict files in the repo
  - Selected file highlighted
  - Shows file name + directory
- **Main Area** (scrollable, remaining width):
  - Full file content rendered as a list of sections
  - **Context sections:** read-only code block with syntax highlighting and line numbers
  - **Conflict blocks:** visually distinct cards with a subtle border/background

### 2. Conflict Block UI

Each conflict block is a card-like section:

- **Header:**
  - Subtle colored banner (e.g., purple tint)
  - Two checkboxes: `[ ] Current` and `[ ] Incoming`
  - If both are checked, the result is `current + incoming` ("Use Both")
  - If a checkbox is unchecked, the corresponding text is removed from the result
  - Manual edits in the Result pane override the checkboxes and switch the resolution to `.manual`
- **Body:**
  - **Top row:** `Current` pane (left) | `Incoming` pane (right)
  - **Bottom row:** `Result` pane (full width, below the two panes)
  - All three panes are code blocks with:
    - Line numbers in a left gutter
    - Syntax highlighting based on the file extension
    - Monospace font
    - Horizontal scroll (no line wrapping), so line numbers stay aligned

### 3. Current / Incoming Panes

- Read-only. Text is selectable for copy.
- Uses `Text` with `AttributedString` for syntax highlighting.
- Line numbers are rendered as a separate column on the left.

### 4. Result Pane

- Editable. Uses `NSTextView` via `NSViewRepresentable`.
- Has line numbers and syntax highlighting.
- No word wrapping (horizontal scroll), so line numbers stay aligned.
- Users can manually edit, copy/paste from other panes.

### 5. Syntax Highlighting

- A lightweight, built-in `SyntaxHighlighter` class.
- Maps file extensions to regex-based color rules.
- Covers: Swift, C/Obj-C, Python, JavaScript/TypeScript, JSON, XML/HTML, Markdown, Go, Rust, Java, Kotlin, Shell, YAML, SQL, and a generic fallback.
- Colors: keywords, strings, comments, numbers, types, operators, attributes/annotations.
- Colors are derived from `NSColor` system colors to respect light/dark mode.

### 6. Interactions

- **Checkboxes:**
  - Checking "Current" fills the Result with the current text.
  - Checking "Incoming" fills the Result with the incoming text.
  - Checking both concatenates them.
  - Unchecking both clears the result.
  - Manual edits in Result override the checkboxes and set resolution to `.manual`.
- **Prev/Next:**
  - Scrolls the main view to the previous/next conflict block.
  - Disabled at boundaries.
- **Complete/Merge:**
  - Saves the resolved file and marks it as resolved in Git.
  - If it's the last unresolved file, closes the modal.
  - If there are remaining unresolved files, moves to the next one.
- **Sidebar file selection:**
  - Clicking a file in the sidebar loads its conflict document.
  - Unsaved changes in the current file trigger a confirmation before switching.

### 7. Removed Elements

- "Resolved File Preview" section
- "Use Current", "Use Incoming", "Use Both" buttons (replaced by per-block checkboxes)

### 8. Files to Create / Modify

| File | Action | Description |
|------|--------|-------------|
| `macgit/Services/SyntaxHighlighter.swift` | Create | Regex-based highlighting engine |
| `macgit/Views/Common/CodeBlockView.swift` | Create | Reusable read-only code block with line numbers and highlighting |
| `macgit/Views/Common/CodeEditorView.swift` | Create | Editable `NSTextView` representable with line numbers and highlighting |
| `macgit/Views/Common/ConflictMergeToolView.swift` | Modify | Full redesign with sidebar, header, and conflict blocks |
| `macgit/Views/FileStatus/FileStatusView.swift` | Modify | Pass all conflict files to the sheet instead of just one file |

## Data Flow

1. `FileStatusView` opens the sheet with a list of all conflict files (`[StatusFile]`) and the initially selected file.
2. `ConflictMergeToolView` loads the conflict document for the selected file.
3. The view renders all sections. For conflict sections, it renders a `ConflictBlockView`.
4. Each `ConflictBlockView` maintains its own state for checkboxes and the result text.
5. Changes to the result text are written back to the `ConflictResolutionDocument`.
6. "Complete" saves the document and advances to the next file (or dismisses).

## Error Handling

- If a file cannot be loaded, show an inline error in the main area instead of a full-screen error.
- If saving fails, show an alert and keep the modal open.
- If the user tries to switch files with unsaved changes, show a confirmation dialog.

## Accessibility

- All checkboxes have clear labels for VoiceOver.
- Prev/Next buttons have descriptive accessibility labels.
- The sidebar file list is a `List` with selection, which is natively accessible.
- The code editor supports standard macOS text editing accessibility.

## Performance

- Syntax highlighting is done lazily per visible block, not for the entire file at once.
- The main area uses a `ScrollView` with `LazyVStack` for large files.
- Attributed string generation is done on a background queue and applied on the main thread.
