# HR Digital - Setup (Hinglish)

1. Flutter SDK + Android Studio install karein.
2. Terminal: `flutter create hr_digital` chalayein, phir is zip ke `lib/` aur `pubspec.yaml` ko us project me copy (replace) karein.
3. Firebase: console.firebase.google.com par project banayein -> Authentication me **Phone** enable -> Firestore Database banayein -> Android app add karke `google-services.json` ko `android/app/` me daalein. Release APK ke liye SHA-1 / SHA-256 bhi Firebase me add karein.
   Easy tareeka: `dart pub global activate flutterfire_cli` phir `flutterfire configure`.
4. ZEGOCLOUD: console.zegocloud.com par project banayein, AppID aur AppSign `lib/meeting_screen.dart` me daalein.
5. `android_snippets/AndroidManifest_permissions.xml` ki lines AndroidManifest.xml me add karein. `android/app/build.gradle` me `minSdkVersion 21` (ya zyada) rakhein.
6. Firestore rules (basic): sirf logged-in staff padh/likh sake:
   ```
   match /staff/{uid} {
     allow read: if request.auth != null;
     allow write: if request.auth != null && request.auth.uid == uid;
   }
   ```
7. `flutter pub get` -> `flutter run` (test) -> `flutter build apk --release`.
   APK: build/app/outputs/flutter-apk/app-release.apk
