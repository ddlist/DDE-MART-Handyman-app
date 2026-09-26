# Firebase setup — DDE Handyman

Push code is wired (`lib/core/push.dart`, token at `POST /worker/push-tokens`
after sign-in; no topic subscription in v1). Only native config is missing.

1. Firebase project: Android app `com.ddemart.dde_handyman`
   (iOS bundle ID identical). May share the project with the other apps.
2. `google-services.json` → `android/app/`;
   `GoogleService-Info.plist` → `ios/Runner/` (add to Xcode).
3. No Dart changes. Without the files, push skips gracefully.
4. Test: sign in — watch logcat for `push:` lines (no news is good news
   until per-worker assignment pushes land).
