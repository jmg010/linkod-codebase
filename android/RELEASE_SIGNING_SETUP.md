# Android Release Signing Setup (LINKod)

This project is configured to use release signing only when `android/key.properties` exists.
If it does not exist, release falls back to debug signing.

## 1) Create a release keystore (one-time)

Run in PowerShell:

```powershell
keytool -genkeypair -v -keystore D:\GitHub\linkod-codebase\android\linkod-release-key.jks -alias linkod_release -keyalg RSA -keysize 2048 -validity 10000
```

Choose and keep these safe:
- keystore password
- key password
- alias (`linkod_release` in command above)

## 2) Create android/key.properties

Copy `android/key.properties.example` to `android/key.properties` and fill real values.

Example:

```properties
storeFile=D:\\GitHub\\linkod-codebase\\android\\linkod-release-key.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=linkod_release
keyPassword=YOUR_KEY_PASSWORD
```

## 3) Verify release signing fingerprint

Run:

```powershell
Set-Location D:\GitHub\linkod-codebase\android
.\gradlew.bat signingReport
```

In output, look for:
- `Variant: release`
- `Config: release`
- SHA1 / SHA-256

If it still says `Config: debug`, recheck `android/key.properties` values.

## 4) Add release SHA in Firebase console

Firebase Console -> Project settings -> Your Android app (`com.example.linkod_admin`) -> SHA certificate fingerprints.

Add both release values:
- SHA-1
- SHA-256

## 5) Download updated google-services.json

Replace:
- `android/app/google-services.json`

## 6) Build release APK

```powershell
Set-Location D:\GitHub\linkod-codebase
flutter clean
flutter pub get
flutter build apk --release
```

## 7) Install and verify OTP behavior

Install the release APK and test phone OTP again on a real device.
Browser reCAPTCHA fallback should happen less often on proper release builds.
