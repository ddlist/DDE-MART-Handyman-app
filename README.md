# DDE-Mart Handyman App

The field-worker Flutter app for the DDE-Mart platform: assigned jobs
with timeline, payouts, SOS and profile — against one backend API. (This
role never had an app before; the worker login exists on the backend
specifically for it.)

- Backend: [DDE-MART-BACKEND](https://github.com/ddlist/DDE-MART-BACKEND) (`master`)
- API reference: `admin-panel/docs/api-v1.md` (Worker section)

## Features

- **Auth** — OTP sign-in (`role=worker`; the provider must register the
  phone first), profile, sign out.
- **My jobs** — provider-assigned bookings, job detail with overlapping
  cards + timeline, machine moves (placed → accepted/rejected/cancelled
  → ongoing → completed).
- **Payouts** — history + requests (bank/paypal/stripe/razorpay/
  flutterwave/cash).
- **SOS** — alert with GPS-filled coordinates.
- **Stories** — promotional strip on the jobs tab.
- **Platform** — launch gate (`/app-config`), admin brand logo in every
  header, FCM push, dark mode, runtime permission flows (location,
  notifications).

## Setup

Prerequisites: Flutter 3.41+ (`flutter doctor` clean), Android Studio or
Xcode, and the backend running (see backend README).

```sh
git clone https://github.com/ddlist/DDE-MART-Handyman-app.git handyman
cd handyman
flutter pub get
```

## Run

```sh
# Herd/Valet domain (default baked into lib/core/config.dart):
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# Android emulator when .test doesn't resolve there:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical phone (same Wi-Fi; backend on 0.0.0.0:8000):
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:8000/api/v1
```

Test accounts: create the worker under a provider in the admin panel
(Providers → Workers, status `active`), then sign in with phone + OTP.
Demo OTP codes appear in the backend log outside production. Seed demo
data with `php artisan db:seed --class=DemoSeeder` (worker
`0303333333`).

## Release build

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
flutter build ipa      --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Push needs `google-services.json` / `GoogleService-Info.plist` per
environment (see `FIREBASE_SETUP.md`) — never committed.

## Verify

```sh
flutter analyze   # clean
flutter test      # 15 tests: jobs, stories, branding, session, nav guards, boot
```

## Support

Installation, tech support, customization: **shariqq.com@gmail.com** ·
WhatsApp **@shareeq9**.

## Credits

Built by [DDLIST](https://ddlist.github.io).

## License

DDLIST Commercial Source License v1.0 � see [LICENSE](LICENSE). You may
use, run, edit, and modify the software for personal or business use,
but you may not resell, redistribute, or republish it.
