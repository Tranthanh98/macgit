# Firebase Setup

Commit+ keeps Firebase configuration local. The app remains usable in guest mode when the configuration file is absent.

## Firebase project

1. Create or select the Firebase project used by Commit+.
2. Register an Apple app with bundle ID `com.thanhtran.macgit`.
3. In Firebase Authentication, enable:
   - Email/Password.
   - Google.
4. Do not enable email verification as an application requirement for the Firebase foundation phases.
5. Create a Cloud Firestore database. Deploy the checked-in Firestore rules before using production data.

## Google OAuth client

Google Sign-In on macOS uses an OAuth client whose application type is **iOS**.

1. Open Google Cloud Console for the same project.
2. Create or verify an iOS OAuth client with bundle ID `com.thanhtran.macgit`.
3. Return to Firebase Authentication, verify Google remains enabled, and download a fresh `GoogleService-Info.plist`.
4. Confirm the downloaded file contains `CLIENT_ID` and `REVERSED_CLIENT_ID`.

## Local app configuration

1. Save the downloaded file at:

   ```text
   macgit/GoogleService-Info.plist
   ```

2. Do not commit this file. The path is ignored by Git.
3. Add the plist's `REVERSED_CLIENT_ID` as a URL scheme for the `macgit` target before enabling the Phase 1 Google sign-in flow.
4. Never print `API_KEY`, OAuth client IDs, or Firebase tokens in test logs.

`FirebaseBootstrap` looks for `GoogleService-Info.plist` in the application bundle. If it is absent or invalid, bootstrap reports `missingConfiguration` and Commit+ continues in guest mode.

## Firebase CLI and emulators

Install and authenticate the Firebase CLI:

```bash
npm install --global firebase-tools
firebase login
firebase use --add
```

Phase 2 adds Firestore and Functions emulator configuration. Run the commands from the repository root so `firebase.json` and rules files resolve consistently.

## Validation

Check required local keys without printing their values:

```bash
for key in BUNDLE_ID PROJECT_ID GOOGLE_APP_ID CLIENT_ID REVERSED_CLIENT_ID IS_SIGNIN_ENABLED; do
  /usr/libexec/PlistBuddy -c "Print :$key" macgit/GoogleService-Info.plist >/dev/null
done
```

The `BUNDLE_ID` value must equal `com.thanhtran.macgit` and `IS_SIGNIN_ENABLED` must be `true`.
