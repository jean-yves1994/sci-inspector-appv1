# SCI Inspector - remove stale Phase-1 files and fix remaining analyzer issues.
#
# Run from the project root (folder containing pubspec.yaml):
#
#     powershell -ExecutionPolicy Bypass -File cleanup.ps1
#
# Every deletion is checked for inbound imports first. If something still
# references a file, it is KEPT and reported rather than silently removed.

$ErrorActionPreference = 'Stop'
$script:Changes = 0

if (-not (Test-Path 'pubspec.yaml')) {
    Write-Host "ERROR: run this from the project root (no pubspec.yaml here)." -ForegroundColor Red
    exit 1
}

function Read-Lf([string]$Path) {
    return [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
}

function Write-Lf([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

# Deletes a superseded file, but only if nothing imports it.
function Remove-Stale {
    param([string]$Path, [string]$Reason)

    if (-not (Test-Path $Path)) {
        Write-Host "  OK    already gone: $Path" -ForegroundColor DarkGray
        return
    }

    $leaf = Split-Path $Path -Leaf
    $referrers = @()
    Get-ChildItem -Path 'lib', 'test' -Filter '*.dart' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne (Resolve-Path $Path).Path } |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            if ($content -match [regex]::Escape("/$leaf'") -or
                $content -match [regex]::Escape("'$leaf'")) {
                $referrers += $_.FullName
            }
        }

    if ($referrers.Count -gt 0) {
        Write-Host "  KEPT  $Path - still imported by:" -ForegroundColor Yellow
        $referrers | ForEach-Object { Write-Host "          $_" -ForegroundColor Yellow }
        return
    }

    Remove-Item $Path -Force
    $script:Changes++
    Write-Host "  DEL   $Path  ($Reason)" -ForegroundColor Green
}

function Edit-File {
    param([string]$Path, [string]$Old, [string]$New, [string]$Label)

    if (-not (Test-Path $Path)) {
        Write-Host "  SKIP  $Label : not found" -ForegroundColor DarkGray
        return
    }
    $src = Read-Lf $Path

    # Sentinel = longest line added by this edit, so re-running is safe.
    $oldSet = @{}
    foreach ($l in $Old -split "`n") { $oldSet[$l.Trim()] = $true }
    $added = @()
    foreach ($l in $New -split "`n") {
        $t = $l.Trim()
        if ($t -and -not $oldSet.ContainsKey($t)) { $added += $t }
    }
    if ($added.Count -gt 0) {
        $marker = ($added | Sort-Object Length -Descending | Select-Object -First 1)
        if ($src.Contains($marker)) {
            Write-Host "  OK    $Label : already applied" -ForegroundColor DarkGray
            return
        }
    }

    if (-not $src.Contains($Old)) {
        Write-Host "  WARN  $Label : pattern not found in $Path" -ForegroundColor Yellow
        return
    }

    $i = $src.IndexOf($Old)
    Write-Lf $Path ($src.Substring(0, $i) + $New + $src.Substring($i + $Old.Length))
    $script:Changes++
    Write-Host "  FIXED $Label" -ForegroundColor Green
}

Write-Host "`nSCI Inspector - cleanup`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------- 1
# Phase-1 placeholder screens. The real implementations live in
# property_screens.dart / inspection_screens.dart / notifications.dart, and
# these leftovers reference PhasePlaceholder, which no longer exists.
Write-Host "1. Removing superseded Phase-1 screens"
Remove-Stale 'lib/features/properties/presentation/property_list_screen.dart'    'superseded by property_screens.dart'
Remove-Stale 'lib/features/inspections/presentation/inspection_list_screen.dart' 'superseded by inspection_screens.dart'
Remove-Stale 'lib/features/notifications/presentation/notifications_screen.dart' 'superseded by notifications.dart'

# ---------------------------------------------------------------------- 2
# ProgressGauge is defined twice: standalone file + sci_widgets.dart.
Write-Host "`n2. Removing duplicate ProgressGauge"
Remove-Stale 'lib/core/widgets/progress_gauge.dart' 'ProgressGauge now lives in sci_widgets.dart'

# ---------------------------------------------------------------------- 3
# Phase-1 split network layer, superseded by the merged interceptors.dart
# and api_client.dart.
Write-Host "`n3. Removing superseded network files"
Remove-Stale 'lib/core/network/interceptors/auth_interceptor.dart'           'merged into interceptors.dart'
Remove-Stale 'lib/core/network/interceptors/retry_interceptor.dart'          'merged into interceptors.dart'
Remove-Stale 'lib/core/network/interceptors/redacting_log_interceptor.dart'  'merged into interceptors.dart'
Remove-Stale 'lib/core/network/dio_provider.dart'                            'merged into api_client.dart'
Remove-Stale 'lib/core/widgets/state_views.dart'                             'merged into sci_widgets.dart'

if ((Test-Path 'lib/core/network/interceptors') -and
    -not (Get-ChildItem 'lib/core/network/interceptors' -Force -ErrorAction SilentlyContinue)) {
    Remove-Item 'lib/core/network/interceptors' -Force
    Write-Host "  DEL   lib/core/network/interceptors/  (empty)" -ForegroundColor Green
}

# ---------------------------------------------------------------------- 4
# Default counter test from `flutter create`; references MyApp, which the
# app does not define (the root widget is SciInspectorApp).
Write-Host "`n4. Removing the generated placeholder test"
Remove-Stale 'test/widget_test.dart' 'flutter create placeholder, references MyApp'

# ---------------------------------------------------------------------- 5
Write-Host "`n5. Missing repository import in property_screens.dart"
Edit-File -Path 'lib/features/properties/presentation/property_screens.dart' `
    -Label 'propertiesRepositoryProvider import' -Old @'
import '../application/property_providers.dart';
'@ -New @'
import '../application/property_providers.dart';
import '../data/properties_repository.dart';
'@

# ---------------------------------------------------------------------- 6
Write-Host "`n6. Unnecessary string interpolation in tests"
Edit-File -Path 'test/sci_test.dart' -Label 'string interpolation' -Old @'
        expect(s.isEditable, editable, reason: '${s.wire}');
'@ -New @'
        expect(s.isEditable, editable, reason: s.wire);
'@

Write-Host "`nDone. $($script:Changes) change(s).`n" -ForegroundColor Cyan
Write-Host "Replace lib/core/network/interceptors.dart with the copy in this"
Write-Host "folder (fixes the unused import + parameter-name lints), then run:"
Write-Host ""
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
