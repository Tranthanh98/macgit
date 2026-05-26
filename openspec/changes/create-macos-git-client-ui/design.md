## Context
The project is a fresh SwiftUI macOS app generated from Xcode’s default template. It currently uses CoreData with a single `Item` entity. We are repurposing it into a Git client. The target aesthetic is macOS 26 — high border radius, generous whitespace, translucent materials, and native Apple styling.

## Goals / Non-Goals
- Goals:
  - Provide a clean, native macOS repository picker on every launch
  - Provide a two-panel main window (sidebar + detail) after repo selection
  - Keep the UI simple and Apple-styled without over-engineering
- Non-Goals:
  - Full Git graph rendering
  - Branch visualization
  - Syntax-highlighted diff views
  - Advanced Git operations (merge, rebase, etc.)

## Decisions
- **SwiftUI + AppKit bridging for folder picker**: Use `NSOpenPanel` via `NSApplication` bridge because SwiftUI’s `fileImporter` is less flexible for directory-only selection and validation on macOS.
- **Recent repo storage**: Use `UserDefaults` with a simple array of `[URL: Date]` encoded as JSON. This avoids keeping CoreData just for recent repos; CoreData is overkill here.
- **Layout**: Use `NavigationSplitView` (macOS 13+) for the main window. It provides the native sidebar/detail behavior and integrates cleanly with SwiftUI selection state.
- **Clone implementation**: For the proposal scope, clone can be a UI flow that validates inputs. Actual `git clone` execution can be done via `Process` in a follow-up change.
- **Styling**: Apply custom `.cornerRadius(16)` or higher on container backgrounds and list rows, use `Color(nsColor: .controlBackgroundColor)` and materials to match macOS 26 style.

## Risks / Trade-offs
- **Risk**: `NavigationSplitView` requires macOS 13+. If deployment target is older, fallback to `HSplitView`.
  - *Mitigation*: Check project settings; default Xcode templates target latest macOS, so this is likely safe.
- **Risk**: Removing CoreData boilerplate may break previews.
  - *Mitigation*: Keep `PersistenceController` stubbed but remove preview data generation.

## Migration Plan
- Remove `Item` entity from `macgit.xcdatamodeld` or leave it unused (no migration needed for a fresh app).
- Replace `ContentView` entirely; old view code can be deleted.

## Open Questions
- None at this time.
