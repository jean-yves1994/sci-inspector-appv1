# The last 2 issues

Down from 15 to 2. Both are files the previous script **kept on purpose**
because something still imported them — it refuses to delete a referenced file
rather than break your build.

```powershell
powershell -ExecutionPolicy Bypass -File finish.ps1
flutter analyze
```

The script also prints a report of every remaining Phase-1 duplicate it can
find, so you'll see whether anything else is still doubled up.

---

## Or fix both by hand — two edits

### 1. `ambiguous_import` — ProgressGauge defined twice

Open `lib\features\home\presentation\home_screen.dart` and **delete** this
import line:

```dart
import '../../../core/widgets/progress_gauge.dart';
```

`sci_widgets.dart` already exports `ProgressGauge`, so the screen keeps
working. Then delete the orphaned file:

```powershell
Remove-Item lib\core\widgets\progress_gauge.dart
```

> **Worth checking:** the path `features\home\presentation\home_screen.dart` is
> the *Phase 1* home screen. The full build puts it at
> `features\home\home_screen.dart`. If both exist, look at
> `lib\app\router\app_router.dart` to see which one it imports and delete the
> other — otherwise you're maintaining two dashboards, and only one is on
> screen. The script does this check automatically.

### 2. `avoid_renaming_method_parameters`

Open `lib\core\network\interceptors\redacting_log_interceptor.dart`, line 38:

```dart
void onResponse(Response<dynamic> response, ResponseInterceptorHandler h) {
```

Change to:

```dart
void onResponse(
  Response<dynamic> response,
  ResponseInterceptorHandler handler,
) {
```

…and update the body, which calls `h.next(response);` → `handler.next(response);`

**Better option if nothing imports it:** the whole `interceptors\` folder was
merged into `lib\core\network\interceptors.dart`. Check first:

```powershell
Select-String -Path lib\*.dart,lib\**\*.dart -Pattern "redacting_log_interceptor"
```

If that returns nothing outside the file itself, just delete the folder:

```powershell
Remove-Item lib\core\network\interceptors\ -Recurse
```

---

## Why these two survived the last pass

`Remove-Stale` scans for inbound imports before deleting. Both files had a
referrer — `progress_gauge.dart` from the Phase-1 home screen,
`redacting_log_interceptor.dart` from whatever still imports the split
interceptor files (most likely `dio_provider.dart`). That guard is deliberate:
deleting a referenced file turns two lint warnings into a broken build.

`finish.ps1` breaks the cycle by removing the *import* first, then deleting the
now-orphaned file.

---

## After this

`flutter analyze` → **No issues found.**

Then run it:

```powershell
flutter run -d chrome --web-port=5555 --web-hostname=localhost --dart-define-from-file=dart_define.development.json
```

Login will fail on CORS until your NestJS `main.ts` has:

```ts
app.enableCors({
  origin: ['http://localhost:5555'],
  credentials: true,
});
```

Redeploy after adding it. If login then returns 401 rather than a network
error, that's progress — it means the request reached your server.
