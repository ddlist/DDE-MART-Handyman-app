# DDE-Mart handyman app (clean-room rebuild)

Fresh Flutter app for provider staff (handymen) against `admin-panel` API v1
worker surfaces (`docs/api-v1.md`, Worker section). No legacy code — this role
never had an app; the backend login was added for it.

## Run

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## What's wired

- Launch gate (`/app-config`, `worker` audience) + maintenance/update screens.
- OTP sign-in (`role=worker`; the provider must register the phone first),
  profile, sign out.
- My jobs: bookings assigned by the provider, detail timeline, machine moves
  (placed → accepted/rejected/cancelled → ongoing → completed).
- Payouts: history + request.
- SOS with manual coordinates.
- Push token register/unregister (see FIREBASE_SETUP.md).

## Next (not yet)

- Worker↔customer chat (threads link providers today; worker inbox pending).
- GPS auto-fill for SOS (manual entry meanwhile).
- Job assignment push topic for workers (backend fan-out targets providers).
- Firebase native files per environment (not in repo).

## Verify

```sh
flutter analyze
flutter test
```
