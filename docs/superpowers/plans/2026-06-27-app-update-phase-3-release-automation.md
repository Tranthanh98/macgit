# Direct App Update Phase 3: Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a signed, notarized, Sparkle-compatible Apple Silicon release from a version tag, upload the ZIP to GitHub Releases, and deploy the generated `appcast.xml` to GitHub Pages only after the release asset is reachable.

**Architecture:** Keep release work outside the app runtime. The workflow will archive the app with Xcode, import signing material into a temporary keychain, notarize and staple the app, package it with `ditto`, verify metadata and Gatekeeper acceptance, build Sparkle's official `generate_appcast` tool from the pinned package checkout, create a release asset URL under GitHub Releases, and deploy a one-file Pages artifact containing `appcast.xml` as the final step.

**Tech Stack:** GitHub Actions, zsh scripts, Xcode command-line tools, `notarytool`, `stapler`, `ditto`, GitHub CLI, Sparkle `generate_appcast`, GitHub Pages actions.

**Design spec:** [docs/superpowers/specs/2026-06-27-app-update-design.md](../specs/2026-06-27-app-update-design.md)

---

## Scope Guard

This phase is only safe to implement after two configuration decisions are explicit:

1. The production Sparkle feed URL in `SUFeedURL` must match the GitHub Pages site that will host `appcast.xml`.
2. The workflow must use GitHub Pages artifact deployment, not a guessed checked-in `docs/appcast.xml` path.

The current repo still points `SUFeedURL` at `https://thanhtran.github.io/macgit/appcast.xml`, while `origin` is `https://github.com/Tranthanh98/macgit.git`. If that URL is intentional because Pages is published from a custom user site, keep it. If not, update `SUFeedURL` first in a separate tiny change before executing this plan.

## File Structure

- Create `.github/workflows/release-app-update.yml`: tag-triggered workflow for archive, notarization, release upload, and Pages deploy.
- Create `scripts/release/import-signing-assets.sh`: create a temporary keychain, import the Developer ID certificate, and decode the App Store Connect API key.
- Create `scripts/release/build-release-archive.sh`: archive the app, copy the signed app out of the `.xcarchive`, and package the ZIP with `ditto`.
- Create `scripts/release/notarize-and-staple.sh`: notarize the ZIP or app bundle and staple the ticket to the app.
- Create `scripts/release/verify-release-metadata.sh`: verify bundle identifiers, versions, `arm64`, signatures, notarization, and Gatekeeper.
- Create `scripts/release/generate-appcast.sh`: build Sparkle's `generate_appcast` from the pinned package checkout and emit `appcast.xml`.
- Create `docs/release/app-update-secrets.md`: exact secret and variable inventory for GitHub Actions setup.

## Required Secrets And Variables

Document these exact names in `docs/release/app-update-secrets.md` and use them consistently in the workflow:

- GitHub Actions secrets:
  - `MACOS_CERTIFICATE_P12_BASE64`
  - `MACOS_CERTIFICATE_PASSWORD`
  - `MACOS_KEYCHAIN_PASSWORD`
  - `APPSTORE_CONNECT_KEY_ID`
  - `APPSTORE_CONNECT_ISSUER_ID`
  - `APPSTORE_CONNECT_API_KEY_BASE64`
  - `SPARKLE_ED25519_PRIVATE_KEY`
- GitHub Actions variables:
  - `SPARKLE_PUBLIC_ED_KEY`
  - `SPARKLE_FEED_URL`

`SPARKLE_FEED_URL` must equal the final production feed URL, for example `https://tranthanh98.github.io/macgit/appcast.xml` or your custom Pages URL if you intentionally keep `https://thanhtran.github.io/macgit/appcast.xml`.

## Task 1: Add Release Script Scaffolding And Secrets Documentation

**Files:**
- Create: `docs/release/app-update-secrets.md`
- Create: `scripts/release/import-signing-assets.sh`
- Create: `scripts/release/build-release-archive.sh`
- Create: `scripts/release/verify-release-metadata.sh`

- [ ] **Step 1: Write the secrets inventory**

Create `docs/release/app-update-secrets.md`:

```markdown
# App Update Release Secrets

## Secrets

- `MACOS_CERTIFICATE_P12_BASE64`: base64-encoded Developer ID Application `.p12`
- `MACOS_CERTIFICATE_PASSWORD`: password for the `.p12`
- `MACOS_KEYCHAIN_PASSWORD`: temporary CI keychain password
- `APPSTORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APPSTORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID
- `APPSTORE_CONNECT_API_KEY_BASE64`: base64-encoded `.p8` contents
- `SPARKLE_ED25519_PRIVATE_KEY`: Sparkle private Ed25519 key text

## Variables

- `SPARKLE_PUBLIC_ED_KEY`: public Ed25519 key embedded in the app build
- `SPARKLE_FEED_URL`: final production appcast URL

## Notes

- Keep the public key in a variable so debug and release builds can use the same workflow value.
- The private key never belongs in the repository.
- The Pages URL here must match `SUFeedURL` in the app target before shipping.
```

- [ ] **Step 2: Create the signing import helper**

Create `scripts/release/import-signing-assets.sh`:

```bash
#!/bin/zsh
set -euo pipefail

RUNNER_TEMP_DIR="${RUNNER_TEMP:?RUNNER_TEMP is required}"
KEYCHAIN_PATH="$RUNNER_TEMP_DIR/app-signing.keychain-db"
CERT_PATH="$RUNNER_TEMP_DIR/developer-id.p12"
API_KEY_PATH="$RUNNER_TEMP_DIR/AuthKey_${APPSTORE_CONNECT_KEY_ID}.p8"

echo "$MACOS_CERTIFICATE_P12_BASE64" | base64 --decode > "$CERT_PATH"
echo "$APPSTORE_CONNECT_API_KEY_BASE64" | base64 --decode > "$API_KEY_PATH"

security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security list-keychains -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -s -k "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
echo "APPSTORE_CONNECT_API_KEY_PATH=$API_KEY_PATH" >> "$GITHUB_ENV"
```

- [ ] **Step 3: Create the archive-and-zip helper**

Create `scripts/release/build-release-archive.sh`:

```bash
#!/bin/zsh
set -euo pipefail

TAG_VERSION="$1"
BUILD_VERSION="$2"

ARCHIVE_PATH="$RUNNER_TEMP/Commit+.xcarchive"
APP_PATH="$RUNNER_TEMP/Commit+.app"
ZIP_NAME="Commit+-${TAG_VERSION}-arm64.zip"
ZIP_PATH="$RUNNER_TEMP/$ZIP_NAME"

xcodebuild archive \
  -project macgit.xcodeproj \
  -scheme macgit \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$TAG_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_VERSION" \
  SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY"

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Commit+.app" "$APP_PATH"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "ARCHIVE_PATH=$ARCHIVE_PATH" >> "$GITHUB_ENV"
echo "APP_PATH=$APP_PATH" >> "$GITHUB_ENV"
echo "ZIP_PATH=$ZIP_PATH" >> "$GITHUB_ENV"
echo "ZIP_NAME=$ZIP_NAME" >> "$GITHUB_ENV"
```

- [ ] **Step 4: Create the release verification helper**

Create `scripts/release/verify-release-metadata.sh`:

```bash
#!/bin/zsh
set -euo pipefail

APP_PATH="$1"
EXPECTED_VERSION="$2"
EXPECTED_BUILD="$3"
EXPECTED_FEED_URL="$4"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/Commit+"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")
MARKETING_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
FEED_URL=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST")
PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST")
ARCHS=$(lipo -archs "$EXECUTABLE_PATH")

test "$BUNDLE_ID" = "com.thanhtran.macgit"
test "$MARKETING_VERSION" = "$EXPECTED_VERSION"
test "$BUILD_VERSION" = "$EXPECTED_BUILD"
test "$FEED_URL" = "$EXPECTED_FEED_URL"
test -n "$PUBLIC_KEY"
test "$ARCHS" = "arm64"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"
```

- [ ] **Step 5: Run script smoke checks**

Run:

```bash
chmod +x scripts/release/import-signing-assets.sh scripts/release/build-release-archive.sh scripts/release/verify-release-metadata.sh
scripts/release/build-release-archive.sh
```

Expected: non-zero exit because required arguments are missing.

## Task 2: Add Notarization And Appcast Generation Helpers

**Files:**
- Create: `scripts/release/notarize-and-staple.sh`
- Create: `scripts/release/generate-appcast.sh`

- [ ] **Step 6: Create the notarization helper**

Create `scripts/release/notarize-and-staple.sh`:

```bash
#!/bin/zsh
set -euo pipefail

ZIP_PATH="$1"
APP_PATH="$2"

xcrun notarytool submit "$ZIP_PATH" \
  --key "$APPSTORE_CONNECT_API_KEY_PATH" \
  --key-id "$APPSTORE_CONNECT_KEY_ID" \
  --issuer "$APPSTORE_CONNECT_ISSUER_ID" \
  --wait

xcrun stapler staple "$APP_PATH"
```

- [ ] **Step 7: Create the appcast generation helper**

Create `scripts/release/generate-appcast.sh`:

```bash
#!/bin/zsh
set -euo pipefail

TAG_NAME="$1"
ZIP_NAME="$2"
ZIP_PATH="$3"
OUTPUT_APPCAST="$4"

SPARKLE_CHECKOUT="$RUNNER_TEMP/SourcePackages/checkouts/Sparkle"
APPCAST_WORK_DIR="$RUNNER_TEMP/appcast-work"
APPCAST_BIN_DIR="$SPARKLE_CHECKOUT/.build/release"
DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG_NAME}/"

rm -rf "$APPCAST_WORK_DIR"
mkdir -p "$APPCAST_WORK_DIR"
cp "$ZIP_PATH" "$APPCAST_WORK_DIR/$ZIP_NAME"

swift build --package-path "$SPARKLE_CHECKOUT" -c release --product generate_appcast

echo "$SPARKLE_ED25519_PRIVATE_KEY" > "$RUNNER_TEMP/sparkle_private_key.txt"

"$APPCAST_BIN_DIR/generate_appcast" \
  --ed-key-file "$RUNNER_TEMP/sparkle_private_key.txt" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  -o "$OUTPUT_APPCAST" \
  "$APPCAST_WORK_DIR"
```

- [ ] **Step 8: Run helper smoke checks**

Run:

```bash
chmod +x scripts/release/notarize-and-staple.sh scripts/release/generate-appcast.sh
scripts/release/generate-appcast.sh
```

Expected: non-zero exit because required arguments are missing.

## Task 3: Add The Release Workflow

**Files:**
- Create: `.github/workflows/release-app-update.yml`

- [ ] **Step 9: Create the workflow**

Create `.github/workflows/release-app-update.yml`:

```yaml
name: Release App Update

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  release:
    runs-on: macos-15
    environment:
      name: github-pages
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Resolve package dependencies into a stable checkout path
        run: |
          xcodebuild -resolvePackageDependencies \
            -project macgit.xcodeproj \
            -scheme macgit \
            -clonedSourcePackagesDirPath "$RUNNER_TEMP/SourcePackages"

      - name: Validate tag and version
        run: |
          TAG_VERSION="${GITHUB_REF_NAME#v}"
          PROJECT_VERSION=$(xcodebuild -project macgit.xcodeproj -scheme macgit -showBuildSettings | awk '/MARKETING_VERSION/ { print $3; exit }')
          test "$TAG_VERSION" = "$PROJECT_VERSION"
          echo "TAG_VERSION=$TAG_VERSION" >> "$GITHUB_ENV"
          echo "BUILD_VERSION=${GITHUB_RUN_NUMBER}" >> "$GITHUB_ENV"

      - name: Import signing assets
        run: scripts/release/import-signing-assets.sh
        env:
          MACOS_CERTIFICATE_P12_BASE64: ${{ secrets.MACOS_CERTIFICATE_P12_BASE64 }}
          MACOS_CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
          MACOS_KEYCHAIN_PASSWORD: ${{ secrets.MACOS_KEYCHAIN_PASSWORD }}
          APPSTORE_CONNECT_KEY_ID: ${{ secrets.APPSTORE_CONNECT_KEY_ID }}
          APPSTORE_CONNECT_ISSUER_ID: ${{ secrets.APPSTORE_CONNECT_ISSUER_ID }}
          APPSTORE_CONNECT_API_KEY_BASE64: ${{ secrets.APPSTORE_CONNECT_API_KEY_BASE64 }}

      - name: Run tests
        run: xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test

      - name: Build release archive
        run: scripts/release/build-release-archive.sh "$TAG_VERSION" "$BUILD_VERSION"
        env:
          SPARKLE_PUBLIC_ED_KEY: ${{ vars.SPARKLE_PUBLIC_ED_KEY }}

      - name: Notarize and staple
        run: scripts/release/notarize-and-staple.sh "$ZIP_PATH" "$APP_PATH"
        env:
          APPSTORE_CONNECT_KEY_ID: ${{ secrets.APPSTORE_CONNECT_KEY_ID }}
          APPSTORE_CONNECT_ISSUER_ID: ${{ secrets.APPSTORE_CONNECT_ISSUER_ID }}

      - name: Verify release metadata
        run: scripts/release/verify-release-metadata.sh "$APP_PATH" "$TAG_VERSION" "$BUILD_VERSION" "${{ vars.SPARKLE_FEED_URL }}"

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" "$ZIP_PATH" \
            --repo "$GITHUB_REPOSITORY" \
            --title "$GITHUB_REF_NAME" \
            --generate-notes

      - name: Verify public release asset
        run: |
          RELEASE_ASSET_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/${GITHUB_REF_NAME}/${ZIP_NAME}"
          curl --fail --location "$RELEASE_ASSET_URL" --output /dev/null
          echo "RELEASE_ASSET_URL=$RELEASE_ASSET_URL" >> "$GITHUB_ENV"

      - name: Generate appcast
        run: scripts/release/generate-appcast.sh "$GITHUB_REF_NAME" "$ZIP_NAME" "$ZIP_PATH" "$RUNNER_TEMP/appcast.xml"
        env:
          GITHUB_REPOSITORY: ${{ github.repository }}
          SPARKLE_ED25519_PRIVATE_KEY: ${{ secrets.SPARKLE_ED25519_PRIVATE_KEY }}

      - name: Prepare GitHub Pages artifact
        run: |
          mkdir -p "$RUNNER_TEMP/pages"
          cp "$RUNNER_TEMP/appcast.xml" "$RUNNER_TEMP/pages/appcast.xml"

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ${{ runner.temp }}/pages

      - name: Deploy Pages site
        uses: actions/deploy-pages@v4
```

- [ ] **Step 10: Add a workflow lint smoke check**

Run:

```bash
python3 - <<'PY'
import pathlib, yaml
path = pathlib.Path(".github/workflows/release-app-update.yml")
with path.open("r", encoding="utf-8") as f:
    yaml.safe_load(f)
print("workflow yaml ok")
PY
```

Expected: `workflow yaml ok`

## Task 4: Self-Review And Commit

**Files:**
- Modify: `docs/superpowers/plans/2026-06-27-app-update-phase-3-release-automation.md`

- [ ] **Step 11: Review the plan against the approved spec**

Confirm these requirements are covered directly in the files above:

```text
- signed and notarized arm64 zip
- Sparkle appcast generation using Ed25519 private key
- GitHub Release asset verified before appcast deployment
- GitHub Pages hosting for the feed
- explicit secret inventory
- feed URL alignment with SUFeedURL
```

Expected: all six items are accounted for in Tasks 1-3.

- [ ] **Step 12: Commit the repaired Phase 3 plan**

Run:

```bash
git add docs/superpowers/plans/2026-06-27-app-update-phase-3-release-automation.md
git commit -m "docs: repair app update phase 3 plan"
```

Expected: a docs-only commit on `main` that replaces the broken Phase 3 draft with an executable plan.
