# Google Play release checklist

## Current status

The app passes local analysis/tests and can build a debug APK. A Play upload must use a real release keystore. The current application ID is `com.example.thelot_2`; choose and confirm a permanent unique ID before the first Play upload because it cannot be changed afterward.

## Configure signing

1. Create an upload keystore outside source control. Keep the passwords in a password manager.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Replace every placeholder value and put the keystore path in `storeFile`.
4. Keep the keystore and `android/key.properties` backed up securely. Losing the upload key can block future updates.

Example keystore command:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Build the Play artifact

Run from the folder containing `pubspec.yaml`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Upload:

```text
build/app/outputs/bundle/release/app-release.aab
```

The release build intentionally fails when `android/key.properties` is missing, preventing an accidental debug-signed upload.

## Play Console items

- Confirm the permanent application ID and app name.
- Complete the store listing, screenshots, feature graphic, category, and contact email.
- Publish a privacy policy URL.
- Complete Data safety and content rating forms.
- Declare the notification permission and explain reminder functionality.
- Test the signed AAB on internal testing before production.
- Test notifications, custom sound, permissions, exact alarms, reboot behavior, offline startup, and Android back navigation on a physical device.
- Increment the version in `pubspec.yaml` for every update, for example `1.0.0+2`.
