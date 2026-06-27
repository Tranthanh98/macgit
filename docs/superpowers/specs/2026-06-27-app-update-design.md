# Direct App Update — Design Spec

**Date:** 2026-06-27
**Status:** Approved (brainstorm phase)
**Distribution:** GitHub Releases, outside the Mac App Store

## Purpose

Add a secure, user-initiated app update experience to Commit+ (macgit). The app checks for a newer stable release at every launch without prompting. When an update is available, repository windows show an **Update** button at the top of the sidebar. The user decides when to open the update flow, download the release, install it, and relaunch.

## Product Decisions

- Distribute directly through GitHub Releases, not the Mac App Store.
- Integrate Sparkle 2 rather than implement app replacement in-house.
- Check update metadata once per app launch without asking permission.
- Never download or install an update automatically.
- Open Sparkle's standard release-notes and installation window when the user clicks **Update**.
- Display only **Update** or **Downloading…** in the sidebar UI; version numbers and detailed progress belong in Sparkle's window.
- Publish Apple Silicon (`arm64`) builds only for the first version.
- Build and publish releases from Git tags with GitHub Actions.
- Require Developer ID signing, hardened runtime, Apple notarization, and Sparkle EdDSA signatures before a release enters the update feed.

## Chosen Approach

Use Sparkle's standard update engine and user interface with a small custom, app-wide SwiftUI state adapter and a custom sidebar banner.

Sparkle owns update discovery, compatibility filtering, archive verification, downloading, installation, and relaunch. Commit+ owns only the launch-time check policy and the compact sidebar entry point. This keeps security-sensitive update mechanics inside a mature updater while preserving the requested product experience.

Alternatives rejected:

1. **Sparkle standard UI without a custom banner** — simpler, but it interrupts the user when an update is found and does not satisfy the proactive sidebar-button requirement.
2. **A fully custom updater** — preserves zero external dependencies, but would make Commit+ responsible for secure download validation, filesystem replacement, privilege handling, failure recovery, and relaunch. The added security and maintenance risk is not justified.

## Architecture

### AppUpdateController

`AppUpdateController` is a main-actor observable object owned once by `macgitApp`. It remains separate from `AppState`: repository/window state and application-update state have different lifetimes and responsibilities.

The controller:

- Owns Sparkle's `SPUStandardUpdaterController`.
- Starts Sparkle and performs one silent background metadata check after app startup.
- Publishes the small amount of state the sidebar needs.
- Brings Sparkle's standard update session into focus when the user requests an update.
- Exposes a manual **Check for Updates…** action for the application menu.
- Adapts Sparkle delegate callbacks without reproducing Sparkle's download or installation logic.

The observable UI state is deliberately small:

```swift
enum AppUpdateState: Equatable {
    case idle
    case checking
    case available
    case downloading
}
```

Sparkle remains the source of truth for the detailed update session. The controller does not persist update state across launches.

### UpdateBannerView

`UpdateBannerView` is a presentation-only SwiftUI component. It receives the current state and an update action. It neither imports Sparkle nor performs network work.

`SidebarView` places the banner above its existing `List` in a `VStack`, keeping the update control anchored while repository sections scroll.

The visible states are:

| State | Sidebar UI |
|---|---|
| `idle` or `checking` | No banner |
| `available` | Enabled **Update** button |
| `downloading` | Disabled **Downloading…** button with an optional small spinner |

No version number, release notes, byte count, percentage, or installation state appears in the sidebar.

### SwiftUI ownership

`macgitApp` creates the single controller and injects it into the environment. All repository windows observe the same instance, so every sidebar agrees about availability and download state. When no repository is open, no sidebar banner is visible, but the application-menu command remains available.

## Update Data Flow

1. Commit+ launches and initializes Sparkle.
2. After the updater is ready, `AppUpdateController` performs one silent background check for the current process launch.
3. Sparkle loads the HTTPS appcast, compares bundle versions, applies compatibility rules, and verifies feed metadata.
4. If there is no eligible release, the controller returns to `idle` and no UI appears.
5. If a newer eligible release exists, the controller publishes `available`; every open repository sidebar shows **Update**.
6. Clicking **Update** asks Sparkle to bring the standard update window into focus. The window displays the release notes and lets the user start the download.
7. Once download begins, the controller publishes `downloading`; the sidebar button becomes disabled and reads **Downloading…**.
8. Sparkle validates the archive, performs installation, and offers to relaunch Commit+.

If the user dismisses the Sparkle window before downloading, the sidebar remains in the `available` state. If the user skips that version, Sparkle suppresses it from automatic checks until a newer release is available; a manual check may bring skipped releases back into consideration according to Sparkle's standard behavior.

## Check Policy and Privacy

Commit+ enables automatic update checks in configuration and does not show Sparkle's opt-in permission prompt. It performs one background metadata check on each process launch. This check does not download the app archive.

The app does not add periodic polling during a long-running session in the first version. Users can run **Check for Updates…** from the application menu whenever they want a fresh check.

## Error Handling

- Background network, DNS, and feed failures remain silent and leave the sidebar hidden.
- A manual **Check for Updates…** request uses Sparkle's standard user-facing feedback.
- Invalid appcast data, incompatible releases, and invalid signatures are rejected; Commit+ never falls back to an unverified artifact.
- Download and installation failures are presented by Sparkle's standard UI.
- Updater failures do not use repository-level `SyncState` alerts and do not post `.repositoryDidChange`.
- If the updater cannot initialize because the application is misconfigured, the failure is logged for diagnosis and manual update checks report the configuration problem.

## Security and Distribution

Every public update must pass two independent trust layers:

1. **Apple trust chain** — the app is signed with a Developer ID Application certificate, uses hardened runtime, is notarized by Apple, and carries a stapled notarization ticket.
2. **Sparkle trust chain** — the update archive and appcast metadata use Sparkle's EdDSA signing. The app bundle contains only the public key; the private key never enters the repository.

The project uses an application ZIP rather than a `.pkg`, so a Developer ID Installer certificate is not required. Release ZIP creation must preserve macOS metadata and signatures.

Secrets stored in GitHub Actions include:

- Developer ID Application certificate export and its password.
- Temporary CI keychain password.
- Apple notarization credentials, preferably an App Store Connect API key.
- Sparkle EdDSA private key material.

Workflow logs must not print secret values. Imported certificates and temporary keychains are removed during job cleanup.

## Automated Release Pipeline

A stable semantic-version tag such as `v1.1.0` starts the GitHub Actions release workflow:

1. Validate the tag format and ensure its semantic version agrees with `MARKETING_VERSION`.
2. Resolve the pinned Sparkle package version.
3. Run the full `xcodebuild test` suite.
4. Archive a Release build for `arm64` with hardened runtime.
5. Sign with the Developer ID Application identity.
6. Submit the archive to Apple's notary service and wait for acceptance.
7. Staple the notarization ticket.
8. Verify the code signature, hardened runtime, notarization, Gatekeeper acceptance, architecture, bundle identifier, marketing version, and build number.
9. Package the application as a metadata-preserving ZIP.
10. Generate the Sparkle EdDSA signature and appcast entry.
11. Publish the ZIP and release notes in a non-draft GitHub Release.
12. Verify the public release asset is reachable.
13. Publish the updated stable `appcast.xml` through GitHub Pages.

The appcast is the final publication step. Any earlier failure leaves the existing feed untouched, so installed clients cannot discover a partial or unusable release.

Only stable, non-draft GitHub Releases enter the first-version appcast. GitHub prereleases are excluded.

## Versioning

- `MARKETING_VERSION` is the user-facing semantic version and must match the release tag after removing the leading `v`.
- `CURRENT_PROJECT_VERSION` maps to `CFBundleVersion`, must be numeric, and must increase for every published build.
- Sparkle compares build versions when determining whether a release is newer.
- The workflow fails before publishing if version validation does not pass.

## Hosting

- GitHub Releases hosts the signed Apple Silicon ZIP and release notes.
- GitHub Pages hosts a stable HTTPS appcast URL.
- The generated Info.plist contains Sparkle's feed URL, public EdDSA key, automatic-check configuration, and automatic-install-disabled configuration.
- The production feed contains only artifacts that completed the full release pipeline.

## Testing

### Unit and integration tests

Sparkle is hidden behind a small updater protocol so tests can inject a fake adapter without accessing the network or displaying updater UI.

Tests cover:

- `idle` and `checking` render no banner.
- `available` renders an enabled **Update** button.
- `downloading` renders a disabled **Downloading…** button.
- Clicking **Update** asks the updater adapter to focus the standard update session.
- The manual menu action requests an explicit update check.
- Multiple repository windows observe the same controller state.
- Background failures remain outside repository error presentation.
- Dismissing before download returns or retains the `available` state.

All non-trivial implementation phases run the full project test command:

```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test
```

### Release verification

The release workflow fails unless it verifies:

- The full test suite passed.
- The app contains only `arm64` executable slices.
- Bundle identifier and versions are correct.
- Code signatures and hardened runtime are valid.
- Apple notarization succeeded and the ticket is stapled.
- Gatekeeper accepts the app.
- The Sparkle signature matches the release ZIP.
- The appcast enclosure metadata matches the uploaded artifact.
- The public asset is reachable before the appcast changes.

### End-to-end acceptance test

Before enabling the production appcast, install an older signed and notarized Commit+ build in `/Applications`, point it at a controlled test feed, and publish a newer signed build. Verify:

1. Launching the old build silently discovers the update.
2. The sidebar shows **Update**.
3. Clicking it opens Sparkle's standard release-notes window.
4. Starting the download changes the sidebar label to **Downloading…**.
5. Sparkle installs the new build and relaunches Commit+.
6. The relaunched app reports the expected new bundle version and no longer shows the banner.

## Implementation Phases

The implementation roadmap will split the feature into independently verifiable phases:

1. **Sparkle foundation and testable controller** — package integration, generated Info.plist settings, state adapter, automatic launch check, manual menu action, and controller tests.
2. **Sidebar update experience** — `UpdateBannerView`, shared environment wiring, `Update`/`Downloading…` states, and focused UI-policy tests.
3. **Signing and release automation** — hardened runtime, release verification scripts, GitHub Actions signing/notarization, GitHub Release publication, and GitHub Pages appcast publication.
4. **End-to-end release qualification** — test-feed upgrade, production-feed enablement checklist, and release documentation.

Each phase is implemented on an isolated `codex/<phase>` branch/worktree. The roadmap remains on `main` and marks a phase completed only after its tests and required release checks pass.

## Out of Scope (First Version)

- Automatic update downloads or silent installation.
- Periodic polling while the same app process remains open.
- Intel (`x86_64`) or universal artifacts.
- Beta, nightly, or multiple update channels.
- Delta update generation.
- Mac App Store distribution.
- Custom release-notes, download-progress, installation, or relaunch UI beyond the two-state sidebar button.
- Rollout percentages or staged deployment cohorts.

## References

- [Sparkle documentation](https://sparkle-project.org/documentation/)
- [Sparkle programmatic SwiftUI setup](https://sparkle-project.org/documentation/programmatic-setup/)
- [Apple Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
