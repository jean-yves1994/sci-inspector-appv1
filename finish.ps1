# SCI Inspector - clear the last 2 analyzer issues, and report any remaining
# duplicate Phase-1 files.
#
#     powershell -ExecutionPolicy Bypass -File finish.ps1

$ErrorActionPreference = 'Stop'
$script:Changes = 0

if (-not (Test-Path 'pubspec.yaml')) {
    Write-Host "ERROR: run from the project root (no pubspec.yaml here)." -ForegroundColor Red
    exit 1
}

function Read-Lf([string]$p) {
    return [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
}
function Write-Lf([string]$p, [string]$t) {
    [System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding $false))
}

# Returns every .dart file that imports the given leaf filename.
function Get-Referrers([string]$Leaf, [string]$SelfPath) {
    $hits = @()
    Get-ChildItem -Path 'lib', 'test' -Filter '*.dart' -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($SelfPath -and $_.FullName -eq $SelfPath) { return }
            $c = Get-Content $_.FullName -Raw
            if ($c -match [regex]::Escape("/$Leaf'") -or $c -match [regex]::Escape("'$Leaf'")) {
                $hits += $_.FullName
            }
        }
    return $hits
}

Write-Host "`nSCI Inspector - final cleanup`n" -ForegroundColor Cyan

# --------------------------------------------------------------------- 1
# ProgressGauge exists in BOTH progress_gauge.dart and sci_widgets.dart.
# The Phase-1 home screen imports both, so the name is ambiguous.
Write-Host "1. Duplicate ProgressGauge"

$phase1Home = 'lib/features/home/presentation/home_screen.dart'
$fullHome   = 'lib/features/home/home_screen.dart'

if ((Test-Path $phase1Home) -and (Test-Path $fullHome)) {
    # Two home screens exist. Keep whichever the router actually imports.
    $routerUsesPhase1 = $false
    if (Test-Path 'lib/app/router/app_router.dart') {
        $r = Get-Content 'lib/app/router/app_router.dart' -Raw
        if ($r -match 'home/presentation/home_screen\.dart') { $routerUsesPhase1 = $true }
    }

    if ($routerUsesPhase1) {
        Write-Host "  INFO  router uses the Phase-1 home screen; keeping it" -ForegroundColor DarkGray
    } else {
        $refs = Get-Referrers 'home_screen.dart' (Resolve-Path $phase1Home).Path
        $external = $refs | Where-Object { $_ -notlike '*\home\presentation\*' }
        if ($external.Count -eq 0) {
            Remove-Item $phase1Home -Force
            $script:Changes++
            Write-Host "  DEL   $phase1Home (superseded, unreferenced)" -ForegroundColor Green
            if (-not (Get-ChildItem 'lib/features/home/presentation' -Force -ErrorAction SilentlyContinue)) {
                Remove-Item 'lib/features/home/presentation' -Force
                Write-Host "  DEL   lib/features/home/presentation/ (empty)" -ForegroundColor Green
            }
        } else {
            Write-Host "  KEPT  $phase1Home - referenced by:" -ForegroundColor Yellow
            $external | ForEach-Object { Write-Host "          $_" -ForegroundColor Yellow }
        }
    }
}

# Whichever home screen survives must not import BOTH gauge sources.
foreach ($h in @($phase1Home, $fullHome)) {
    if (-not (Test-Path $h)) { continue }
    $src = Read-Lf $h
    if ($src -match "import '[^']*progress_gauge\.dart';\n") {
        $src = [regex]::Replace($src, "import '[^']*progress_gauge\.dart';\n", '')
        Write-Lf $h $src
        $script:Changes++
        Write-Host "  FIXED removed progress_gauge.dart import from $h" -ForegroundColor Green
    }
}

# Now the standalone gauge file should be orphaned.
if (Test-Path 'lib/core/widgets/progress_gauge.dart') {
    $refs = Get-Referrers 'progress_gauge.dart' (Resolve-Path 'lib/core/widgets/progress_gauge.dart').Path
    if ($refs.Count -eq 0) {
        Remove-Item 'lib/core/widgets/progress_gauge.dart' -Force
        $script:Changes++
        Write-Host "  DEL   lib/core/widgets/progress_gauge.dart (now unreferenced)" -ForegroundColor Green
    } else {
        Write-Host "  KEPT  progress_gauge.dart - still imported by:" -ForegroundColor Yellow
        $refs | ForEach-Object { Write-Host "          $_" -ForegroundColor Yellow }
    }
}

# --------------------------------------------------------------------- 2
# The split Phase-1 interceptor files. Delete if orphaned, otherwise just
# rename the offending parameter so the lint clears either way.
Write-Host "`n2. redacting_log_interceptor.dart"

$rli = 'lib/core/network/interceptors/redacting_log_interceptor.dart'
if (Test-Path $rli) {
    $refs = Get-Referrers 'redacting_log_interceptor.dart' (Resolve-Path $rli).Path
    if ($refs.Count -eq 0) {
        Remove-Item $rli -Force
        $script:Changes++
        Write-Host "  DEL   $rli (unreferenced; merged into interceptors.dart)" -ForegroundColor Green
    } else {
        # Still imported - fix the lint in place rather than breaking the build.
        Write-Host "  INFO  still imported by:" -ForegroundColor DarkGray
        $refs | ForEach-Object { Write-Host "          $_" -ForegroundColor DarkGray }
        $src = Read-Lf $rli
        $old = 'void onResponse(Response<dynamic> response, ResponseInterceptorHandler h) {'
        $new = 'void onResponse(' + "`n" +
               '    Response<dynamic> response,' + "`n" +
               '    ResponseInterceptorHandler handler,' + "`n" +
               '  ) {'
        if ($src.Contains($old)) {
            $src = $src.Replace($old, $new)
            # Rewrite the body's use of the old short name.
            $src = $src.Replace('    h.next(response);', '    handler.next(response);')
            Write-Lf $rli $src
            $script:Changes++
            Write-Host "  FIXED renamed 'h' to 'handler'" -ForegroundColor Green
        } else {
            Write-Host "  WARN  pattern not found - fix line 38 by hand" -ForegroundColor Yellow
        }
    }
}

# Drop the folder if it is now empty.
if ((Test-Path 'lib/core/network/interceptors') -and
    -not (Get-ChildItem 'lib/core/network/interceptors' -Force -ErrorAction SilentlyContinue)) {
    Remove-Item 'lib/core/network/interceptors' -Force
    Write-Host "  DEL   lib/core/network/interceptors/ (empty)" -ForegroundColor Green
}

# --------------------------------------------------------------------- 3
Write-Host "`n3. Remaining duplicate-file report" -ForegroundColor Cyan

$dupes = @(
    @('lib/core/widgets/progress_gauge.dart',                              'sci_widgets.dart'),
    @('lib/core/widgets/state_views.dart',                                 'sci_widgets.dart'),
    @('lib/core/network/dio_provider.dart',                                'api_client.dart'),
    @('lib/core/network/interceptors/auth_interceptor.dart',               'interceptors.dart'),
    @('lib/core/network/interceptors/retry_interceptor.dart',              'interceptors.dart'),
    @('lib/core/network/interceptors/redacting_log_interceptor.dart',      'interceptors.dart'),
    @('lib/features/home/presentation/home_screen.dart',                   'features/home/home_screen.dart'),
    @('lib/features/properties/presentation/property_list_screen.dart',    'property_screens.dart'),
    @('lib/features/properties/presentation/property_detail_screen.dart',  'property_screens.dart'),
    @('lib/features/properties/presentation/create_property_screen.dart',  'property_screens.dart'),
    @('lib/features/properties/presentation/widgets/property_card.dart',   'property_screens.dart'),
    @('lib/features/properties/application/property_list_notifier.dart',   'property_providers.dart'),
    @('lib/features/properties/application/property_detail_provider.dart', 'property_providers.dart'),
    @('lib/features/properties/application/create_property_controller.dart','property_providers.dart'),
    @('lib/features/properties/domain/property_type.dart',                 'domain/property.dart'),
    @('lib/features/properties/domain/create_property_request.dart',       'domain/property.dart'),
    @('lib/features/inspections/presentation/inspection_list_screen.dart', 'inspection_screens.dart'),
    @('lib/features/notifications/presentation/notifications_screen.dart', 'notifications/notifications.dart'),
    @('lib/features/profile/presentation/profile_screen.dart',             'features/profile/profile_screen.dart'),
    @('lib/features/auth/presentation/login_screen.dart',                  'auth_screens.dart'),
    @('lib/features/auth/presentation/forgot_password_screen.dart',        'auth_screens.dart'),
    @('lib/features/auth/presentation/reset_password_screen.dart',         'auth_screens.dart'),
    @('lib/features/auth/presentation/change_password_screen.dart',        'auth_screens.dart'),
    @('lib/features/auth/presentation/widgets/auth_scaffold.dart',         'auth_screens.dart'),
    @('lib/features/auth/presentation/widgets/sci_text_field.dart',        'sci_widgets.dart'),
    @('lib/features/splash/presentation/splash_screen.dart',               'features/splash/splash_screen.dart'),
    @('lib/features/splash/application/bootstrap_provider.dart',           'splash_screen.dart'),
    @('test/auth_test.dart',                                               'sci_test.dart'),
    @('test/properties_test.dart',                                         'sci_test.dart'),
    @('test/widget_test.dart',                                             'sci_test.dart')
)

$found = 0
foreach ($d in $dupes) {
    if (Test-Path $d[0]) {
        $found++
        $leaf = Split-Path $d[0] -Leaf
        $refs = Get-Referrers $leaf (Resolve-Path $d[0]).Path
        $status = if ($refs.Count -eq 0) { "ORPHAN - safe to delete" }
                  else { "imported by $($refs.Count) file(s)" }
        Write-Host ("  {0,-62} -> {1}" -f $d[0], $status) -ForegroundColor Yellow
    }
}
if ($found -eq 0) {
    Write-Host "  None. The Phase-1 tree is fully removed." -ForegroundColor Green
}

Write-Host "`nDone. $($script:Changes) change(s).`n" -ForegroundColor Cyan
Write-Host "  flutter analyze"
