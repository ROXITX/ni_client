# Running the NI Client App

To run or build your app in the different environments, you need to set the `useTestDatabase` flag in your code and then use the correct build command for your target platform.

First, open **`lib/core/config/app_config.dart`**.

## 1. To run the TEST Environment (Dev)

1. Ensure `useTestDatabase = true;` inside `app_config.dart`.
2. Depending on your platform, run the app using the `dev` flavor:

**For Android (Device/Emulator):**
```bash
flutter run --flavor dev -t lib/main.dart
```

**For Chrome / Web:**
*(Web doesn't use Android Flavors, so you just run it normally and it uses `firebase_options_dev.dart` automatically)*
```bash
flutter run -d chrome
```

---

## 2. To run the PRODUCTION Environment (Prod)

1. Ensure `useTestDatabase = false;` inside `app_config.dart`.
2. Depending on your platform, run the app using the `prod` flavor:

**For Android (Device/Emulator):**
```bash
flutter run --flavor prod -t lib/main.dart
```

**For Chrome / Web:**
```bash
flutter run -d chrome
```

---

## 📦 Building APKs

If you want to build a standalone APK file to install on your phone or send to someone else:

**Test APK:**
```bash
flutter build apk --flavor dev -t lib/main.dart
```

**Production APK:**
```bash
flutter build apk --flavor prod -t lib/main.dart
```
