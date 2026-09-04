# SCI Inspector — Flutter App

Field application for the **Smart Collateral Inspection** platform.

**Stack:** Flutter · Dio · Riverpod · go_router · feature-oriented architecture
**API:** `https://sci-server.vercel.app/api/v1` (pre-configured)

---

## Run it in Chrome (no emulator needed)

```bash
unzip sci_inspector.zip && cd sci

# Generate platform folders (does NOT overwrite lib/, but DOES overwrite web/index.html)
cp web/index.html /tmp/sci_index.html
flutter create . --project-name sci_inspector --platforms=web,android,ios
cp /tmp/sci_index.html web/index.html

flutter pub get
flutter run -d chrome --web-port=5555 --web-hostname=localhost \
  --dart-define-from-file=dart_define.development.json
```

### ⚠️ You must whitelist the web origin in the backend

Browser requests are blocked by CORS before Dio ever sees them. In your NestJS
`main.ts`:

```ts
app.enableCors({
  origin: ['http://localhost:5555'],
  credentials: true,
});
```

That is why the run command pins `--web-port=5555` instead of letting Chrome
pick a random port. Redeploy the backend after changing this.

### Verify the API is reachable first

```bash
curl -i https://sci-server.vercel.app/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"inspector@sci.rw","password":"YOUR_PASSWORD","platform":"web"}'
```

---

## What is implemented

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Foundation: theme, router, Dio + interceptors, secure storage, auth, splash | ✅ |
| 2 | Properties: list, search, pagination, detail, create | ✅ |
| 3 | Inspections: list, filters, detail, create, start, status handling | ✅ |
| 4 | Dynamic template form: fetch template, all 11 field types, autosave, version conflict | ✅ |
| 5 | Evidence: assessments, owner, valuation, GPS, photo capture/upload/delete | ✅ |
| 6 | Completeness & submission: gauge, outstanding items, deep-link, submit, corrections, resubmit | ✅ |
| 7 | Offline: local drafts, mutation queue, background sync | ❌ **not built** |
| 8 | Notifications: list, unread badge, mark read, deep-link | ✅ (push registration ❌) |
| 9 | Production hardening: obfuscated builds, store config, integration tests | ⚠️ partial |

### Phase 7 and push notifications are genuinely absent

The app currently requires connectivity. There is no Drift database, no
`PendingMutation` queue, and no sync engine. Autosave posts directly to the
server and surfaces a failure if offline — work is **not** yet preserved
across an app restart while disconnected. For a field app this is the most
important remaining gap.

---

## Architecture

```
lib/
├── app/          router, shell, bottom nav, mobile frame
├── core/         config, network (Dio + interceptors), storage, theme,
│                 location, shared widgets, validators
└── features/
    └── <feature>/{domain, data, application, presentation}
```

- Widgets never touch Dio: **widget → provider → repository → ApiClient**.
- Features import `core`, and another feature's `domain` only.
- The backend is authoritative for permissions, completeness, status
  transitions, GPS verdicts and photo validation. Client checks are UX only.

---

## Key behaviours worth knowing

**Token refresh is single-flight.** `AuthInterceptor` extends
`QueuedInterceptor` and guards refresh with a `Completer`, so N concurrent
401s trigger exactly one refresh. This matters because the backend rotates
refresh tokens and revokes the previous one — parallel refreshes would revoke
each other mid-inspection.

**Network failure never signs you out.** Only `AUTH_TOKEN_INVALID` /
`AUTH_SESSION_REVOKED` / a 401 on refresh clears the session. Timeouts and
5xx are surfaced as retryable.

**Optimistic concurrency is respected.** Every mutation sends `baseVersion`.
On `INSPECTION_STALE_VERSION` the workspace shows a blocking banner with a
*Refresh inspection* action and does **not** overwrite server data.

**The form is never hard-coded.** Sections, fields, options and photo rules
all render from the backend template, so admins can change the form without
shipping a new app. Unknown field types render read-only instead of crashing.

**No reviewer surface.** There is no approve/reject/assign UI anywhere, and a
test asserts the inspector never holds any of the seven reviewer-only
permissions.

---

## Web compatibility rules (keep these when extending)

- Check `kIsWeb` **before** `Platform.isAndroid` — reversed, the web build
  throws at runtime.
- Never reference `dart:io` `File` in shared code. Use `EvidenceFile`
  (`Uint8List bytes` + optional `path`).
- Photo upload uses `MultipartFile.fromBytes` — `fromFile` does not exist on
  web.
- `geolocator` needs a secure context; `localhost` qualifies. Browser fixes
  are reported as `source: "NETWORK"`.
- Tokens are held **in memory only** on web and clear on reload. Browser mode
  is development/QA, not production.

---

## Verify

```bash
flutter analyze
flutter test
```
