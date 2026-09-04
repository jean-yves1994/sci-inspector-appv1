# SCI Inspector — Flutter App (Phase 1 Foundation)

Field application for the **Smart Collateral Inspection** platform.

**Stack:** Flutter · Dio · Riverpod · go_router · feature-oriented architecture

---

## Quick start (Chrome — no emulator required)

```bash
# 1. Generate the platform folders into this project
flutter create . --project-name sci_inspector --platforms=web,android,ios

# 2. Install packages
flutter pub get

# 3. Run in Chrome on a FIXED port so the backend can whitelist the origin
flutter run -d chrome --web-port=5555 --web-hostname=localhost \
  --dart-define-from-file=dart_define.development.json
```

> `flutter create .` will not overwrite the files in this repo — but it does
> regenerate `web/index.html`. Restore the branded version afterwards:
> `git checkout web/index.html`.

### Backend CORS

Chrome debug builds are served from a fixed origin above, so add it in the
NestJS backend:

```ts
app.enableCors({
  origin: ['http://localhost:5555'],
  credentials: true,
});
```

Without this, every request fails at the browser before reaching Dio.

### Splash asset

Drop `sci_logo.png` into `assets/splash/`, then:

```bash
dart run flutter_native_splash:create
```

Until then, the in-app splash renders a vector "SCI" placeholder — the app
still runs.

---

## Verify

```bash
flutter analyze
flutter test
```

---

## What Phase 1 delivers

| Area | Status |
| --- | --- |
| Feature-first project structure | ✅ |
| Theme from brand `#2747AA` (light + dark, M3) | ✅ |
| `go_router` + auth redirect + `mustChangePassword` guard | ✅ |
| Floating rounded bottom nav with raised centre action | ✅ |
| Native + in-app animated splash, HTML loader for web | ✅ |
| Dio client with auth / retry / redacting-log interceptors | ✅ |
| Single-flight token refresh with rotation + one retry | ✅ |
| `ApiError` normalisation of all backend domain codes | ✅ |
| Secure token storage (keystore native / in-memory web) | ✅ |
| Login, forgot password, reset password, change password | ✅ |
| Session restore via `/auth/me`, logout | ✅ |
| Permission gate (`hasPermissionProvider`) | ✅ |
| Design system: gauge, stat cards, alert tiles, badges | ✅ |
| Unit tests for errors, tokens, permissions | ✅ |

**Deferred by design:** properties (Phase 2), inspections (Phase 3), dynamic
template form (Phase 4), evidence (Phase 5), completeness/submission
(Phase 6), offline queue (Phase 7), notifications (Phase 8).

---

## Architecture rules

```
lib/
├── app/          # router, shell, bottom nav, mobile frame
├── core/         # config, network, storage, theme, shared widgets, utils
└── features/
    └── <feature>/
        ├── data/          # APIs + repositories (Dio lives here)
        ├── domain/        # models + enums, no Flutter imports
        ├── application/   # Riverpod notifiers/providers
        └── presentation/  # screens + widgets (no Dio, no Drift)
```

- A feature may import `core`, and another feature's `domain` **only**.
- Widgets never call Dio directly: **widget → provider → repository → Dio**.
- The backend is authoritative for permissions, completeness, status
  transitions, GPS verdicts and photo validation. Client-side checks are UX
  only.

---

## Security notes

- Refresh tokens are rotated by the backend; the stored value is replaced on
  every successful refresh and the previous token is never reused.
- The log interceptor is `kDebugMode`-only and redacts `Authorization`,
  passwords, tokens and `nationalId`.
- A network failure or a 5xx **never** signs the inspector out — only a
  genuinely invalid/revoked session does.
- **Web builds are development/QA only.** Browser storage is not a hardware
  keystore, so tokens are held in memory and cleared on reload. The login
  screen displays a notice when running this way.

---

## Web compatibility rules (keep these when extending)

- Check `kIsWeb` **before** touching `Platform` — otherwise the web build
  throws at runtime.
- Never reference `dart:io` `File` in shared code; use an `EvidenceFile`
  abstraction (`Uint8List bytes` + optional `path`).
- Photo uploads must branch: `MultipartFile.fromBytes` on web,
  `MultipartFile.fromFile` on mobile.
- `geolocator` needs a secure context; `localhost` qualifies, so
  `flutter run -d chrome` works. Map browser fixes to `source: "NETWORK"`.
- Skip `firebase_messaging` registration on web unless configured.
