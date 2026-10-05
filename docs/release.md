# Release builds and signing

Release builds of the Android app are signed with Tabital's **upload key**, never the debug key. The key and its passwords never go into git.

## How it works

`app/android/app/build.gradle.kts` reads `app/android/key.properties`.

- **If the file exists,** the release build is signed with the keystore it names.
- **If it doesn't,** the release build is left **unsigned** and Gradle prints a warning. An unsigned APK can't be installed, which is deliberate: a release is never quietly signed with the debug key.

`key.properties`, `*.jks` and `*.keystore` are listed in `app/android/.gitignore`.

## One-time setup (done by you or the founder, not by Claude)

1. Create the upload keystore **outside the project folder**, for example in `C:\Users\LENOVO\keys\`. Use the JDK in `C:\Users\LENOVO\dev`:

   ```bash
   "C:/Users/LENOVO/dev/jdk-17.0.20.1+1/bin/keytool" -genkeypair -v -keystore C:/Users/LENOVO/keys/tabital-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   It asks for a keystore password, a key password and the certificate details, such as Tabital Pay Ltd and Accra, GH.

2. Create `app/android/key.properties` with:

   ```properties
   storePassword=<the keystore password>
   keyPassword=<the key password>
   keyAlias=upload
   storeFile=C:/Users/LENOVO/keys/tabital-upload.jks
   ```

3. **Back up the keystore and both passwords** somewhere safe, such as a password manager or an offline copy. If they're lost, updates can't be signed with the same key. With Play App Signing, Google can reset an upload key, but it takes time.

## Building a release

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<production API>
```

The Play Store takes the `.aab` from `build/app/outputs/bundle/release/`. Turn on **Play App Signing** when you first upload, so Google holds the app signing key and this file is only the upload key.

## Before the first store release

These are tracked in `docs/guide_checklist.md`:
- the real logo and app icon (B1)
- the Play listing and the data safety form (B3)
- the production API URL
- a check that the release build has no `localhost` or `10.0.2.2` API address
