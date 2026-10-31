# Release builds and signing

Release builds of the Android app are signed with Tabital's **upload key**, never the debug key. The key and its passwords never go into git.

## How it works

`app/android/app/build.gradle.kts` reads `app/android/key.properties`.

- **If the file exists,** the release build is signed with the keystore it names.
- **If it doesn't,** the release build is left **unsigned** and Gradle prints a warning. An unsigned APK can't be installed, which is deliberate: a release is never quietly signed with the debug key.

`key.properties`, `*.jks` and `*.keystore` are listed in `app/android/.gitignore`.

**Local setup completed 28 October 2026:** the upload keystore is at `~/TabitalKeys/tabital-client-upload.jks`, and the ignored `app/android/key.properties` contains the generated passwords and path. Both files are mode `600`. Back up the keystore and both passwords in a separate secure location before uploading the first bundle. The public upload certificate SHA-256 fingerprint is `4F:9F:9E:F5:6D:E1:97:73:AA:B3:44:A9:A2:16:8A:76:6A:22:85:EC:C4:4E:94:66:14:F3:6E:70:0F:30:E9:9F`.

## One-time Android upload key setup

1. Create the upload keystore **outside the project folder**. On macOS, choose a private path such as `~/TabitalKeys/tabital-upload.jks` and run:

   ```bash
   mkdir -p ~/TabitalKeys
   keytool -genkeypair -v -keystore ~/TabitalKeys/tabital-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   On Windows, use a path such as `C:\Users\LENOVO\keys\tabital-upload.jks`:

   ```bash
   "C:/Users/LENOVO/dev/jdk-17.0.20.1+1/bin/keytool" -genkeypair -v -keystore C:/Users/LENOVO/keys/tabital-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   It asks for a keystore password, a key password and the certificate details, such as Tabital Pay Ltd and Accra, GH.

2. Create `app/android/key.properties` with:

   ```properties
   storePassword=<the keystore password>
   keyPassword=<the key password>
   keyAlias=upload
   storeFile=/absolute/path/to/tabital-upload.jks
   ```

3. **Back up the keystore and both passwords** somewhere safe, such as a password manager or an offline copy. If they're lost, updates can't be signed with the same key. With Play App Signing, Google can reset an upload key, but it takes time.

## Building a release

```bash
flutter build appbundle --release
```

The Play Store takes the `.aab` from `build/app/outputs/bundle/release/`. Turn on **Play App Signing** when you first upload, so Google holds the app signing key and this file is only the upload key.

The signed bundle built on 28 October 2026 is `app/build/app/outputs/bundle/release/app-release.aab`. It has application ID `com.tabitalpay.client`, version `1.0.0` / code `1`, and target API 36. `jarsigner -verify` reports `jar verified`. For the next release, increment the `+` build number in `app/pubspec.yaml` before building.

## Before the first store release

These are tracked in `docs/guide_checklist.md`:
- the real logo and app icon (B1)
- the Play listing and the data safety form (B3)
- the API address: release builds default to the live API, `https://tabital-backend.onrender.com` (`lib/core/config.dart`)
- a check that the release build has no `localhost` or `10.0.2.2` API address

## iOS build

The iOS project is in `app/ios`. It uses bundle ID `com.tabitalpay.client`, deployment target iOS 15, the Tabital icon, and camera and photo library permission descriptions. Register this exact ID in the intended Apple Developer organization before publishing; changing it after a store listing exists creates a different app. Confirm the signing team in Xcode, then run `flutter build ipa --release` from `app/`. Upload and test through TestFlight before submitting. The local unsigned validation command is `flutter build ios --release --no-codesign --no-pub`.

On this Mac, MacPorts puts its `rsync` before Apple's system copy. Xcode's IPA export fails with `exportArchive Copy failed` unless the system directories come first. From `app/`, use:

```bash
PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$HOME/Downloads/develop/flutter/bin" flutter build ipa --release --no-pub
```

The signed IPA is written to `app/build/ios/ipa/tabital_pay.ipa`. Check its bundle ID, signing team, and version before uploading.

## Release gates still needing product or account work

- **Account deletion:** Sign-up exists, but the app and backend have no account deletion flow. Implement a clear Account screen action and a backend deletion request that explains any legally retained financial records. Publish a working web deletion request page for Play Console's Data safety form. Verify both routes end to end before submission.
- **iOS screenshot privacy:** Android protects payment and identity screens with `FLAG_SECURE`; iOS has no equivalent API. The iOS scene now covers the app when it leaves the foreground, but users can still take screenshots while it is active. Verify the app-switcher cover on a real iPhone and review whether any further product restrictions are needed.
- **Signing:** create and back up the Android upload key, configure `app/android/key.properties`, and set the Apple Developer team and distribution certificate. Do not upload an unsigned or debug-signed build.
- **Store accounts and metadata:** confirm the final package/bundle IDs, app ownership, support contact, privacy policy, screenshots, age/content rating, Play Data safety, Apple App Privacy, and reviewer credentials. These declarations need to match the live app and backend.
- **Device verification:** test sign-up, login, account recovery, identity capture and document upload, shopping, Paystack return and verification, notifications, and deletion on physical Android and iPhone devices against the production API. Provide a funded or sandbox review account and any instructions Apple needs to reach protected screens.

As of 27 October 2026, Google Play requires new apps and updates to target Android API 36 or later; Apple requires uploads built with Xcode 26 or later and an iOS 26 SDK, and the app must target iOS 13 or later. Recheck the store requirements when submitting. See `docs/store_submission.md` for the store setup sequence and draft listing copy.
