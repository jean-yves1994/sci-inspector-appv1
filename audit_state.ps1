# =============================================================================
# SCI - report which patches are actually present in the codebase.
#
#   powershell -ExecutionPolicy Bypass -File audit_state.ps1
#
# Read-only. Changes nothing. Run from the Flutter project root.
#
# You have received many incremental patches. Before diagnosing further I need
# to know which of them are actually in the code, because a fix that was never
# applied looks identical to a fix that did not work.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()

function Check {
    param(
        [string]$Name,
        [string]$File,
        [string]$Pattern,
        [ValidateSet('Present', 'Absent')][string]$Expect = 'Present',
        [string]$Meaning
    )

    if (-not (Test-Path $File)) {
        $script:results += [pscustomobject]@{
            Check = $Name; State = 'NO FILE'; Detail = $File
        }
        return
    }

    $found = Select-String -Path $File -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue
    $ok = if ($Expect -eq 'Present') { $found } else { -not $found }

    $script:results += [pscustomobject]@{
        Check  = $Name
        State  = if ($ok) { 'OK' } else { 'MISSING' }
        Detail = if ($ok) { '' } else { $Meaning }
    }
}

Write-Host "`nSCI codebase audit`n" -ForegroundColor Cyan

$providers = 'lib\features\inspections\application\inspection_providers.dart'
$repo      = 'lib\features\inspections\data\inspections_repository.dart'
$domain    = 'lib\features\inspections\domain\inspection.dart'
$screen    = 'lib\features\inspections\presentation\workspace\inspection_workspace_screen.dart'
$sections  = 'lib\features\inspections\presentation\workspace\section_pages.dart'
$widgets   = 'lib\core\widgets\sci_widgets.dart'
$apiError  = 'lib\core\network\api_error.dart'

# --- fix3: version adopted from any response shape ---
Check -Name 'MutationResult reads version from any shape' -File $repo `
      -Pattern '_readVersion' `
      -Meaning 'Saves still discard the version the backend returns.'

Check -Name 'MutationResult exposes version field' -File $repo `
      -Pattern 'final int\? version' `
      -Meaning 'MutationResult has no version field.'

# --- fix3: deadlock removed ---
Check -Name 'Deadlock guard removed from flush()' -File $providers `
      -Pattern '_dirty\.isEmpty \|\| _s\.staleVersion' -Expect Absent `
      -Meaning 'flush() still refuses to save once staleVersion latches true.'

Check -Name 'Deadlock guard removed from onFieldChanged()' -File $providers `
      -Pattern 'if \(_s\.staleVersion\) return;' -Expect Absent `
      -Meaning 'onFieldChanged() still suppresses saves after a conflict.'

Check -Name 'Auto-retry after first conflict' -File $providers `
      -Pattern '_conflictRetried' `
      -Meaning 'No self-healing: a conflict requires manual UI recovery.'

# --- fix3: adopt version without refetch ---
Check -Name 'Adopts version without refetch' -File $providers `
      -Pattern 'result\.version != null' `
      -Meaning '_applyMutationResult still refetches, leaving a race window.'

Check -Name 'Inspection.copyWith exists' -File $domain `
      -Pattern 'Inspection copyWith' `
      -Meaning 'Cannot adopt a version without a full refetch.'

# --- fix4: conflict UI ---
Check -Name 'ConflictBanner file exists' `
      -File 'lib\features\inspections\presentation\workspace\conflict_banner.dart' `
      -Pattern 'class ConflictBanner' `
      -Meaning 'The non-destructive recovery UI is not in the project.'

Check -Name 'ConflictBanner wired into the workspace' -File $screen `
      -Pattern 'ConflictBanner\(' `
      -Meaning 'Workspace still shows the banner whose only action DELETES unsaved edits.'

Check -Name 'Destructive reload() banner removed' -File $screen `
      -Pattern '\.reload\(\),' -Expect Absent `
      -Meaning 'The "Refresh inspection" button still calls discardAndReload().'

# --- fix4: provider cycle ---
Check -Name 'completenessProvider does not watch the workspace' -File $providers `
      -Pattern 'ref\.watch\(inspectionWorkspaceProvider\(id\)\)\.valueOrNull\?\.completeness' -Expect Absent `
      -Meaning 'Circular dependency: progress bar rebuilds on every keystroke.'

# --- photo queue bypass ---
Check -Name 'Photo writes signal the workspace' -File $sections `
      -Pattern 'externalWriteProvider|resyncAfterExternalWrite' `
      -Meaning 'Photo upload/delete bypass the mutation queue; the workspace version goes stale.'

# --- error visibility ---
Check -Name 'ErrorStateView shows non-ApiError detail in debug' -File $widgets `
      -Pattern 'runtimeType' `
      -Meaning 'A Dart exception still shows only "Something went wrong."'

Check -Name 'ApiError handles the nested {error:{...}} envelope' -File $apiError `
      -Pattern "nested is Map|root\['error'\] is Map" `
      -Meaning 'SCI domain errors may still crash or be misparsed.'

# --- report ---
$results | Format-Table -AutoSize

$missing = @($results | Where-Object { $_.State -ne 'OK' })

Write-Host ""
if ($missing.Count -eq 0) {
    Write-Host "All patches present. The bug is elsewhere - send the diagnostic output." -ForegroundColor Green
} else {
    Write-Host "$($missing.Count) patch(es) NOT applied:" -ForegroundColor Yellow
    foreach ($m in $missing) {
        Write-Host ("  - {0}`n      {1}" -f $m.Check, $m.Detail) -ForegroundColor Yellow
    }
    Write-Host "`nThis is very likely why the error persists." -ForegroundColor Yellow
}

# --- build freshness ---
Write-Host "`n--- Build freshness ---" -ForegroundColor Cyan
if (Test-Path '.dart_tool') {
    $age = (Get-Date) - (Get-Item '.dart_tool').LastWriteTime
    Write-Host ("  .dart_tool last written {0:N0} minutes ago" -f $age.TotalMinutes)
    if ($age.TotalHours -gt 1) {
        Write-Host "  Stale. Run: flutter clean; flutter pub get" -ForegroundColor Yellow
    }
}
Write-Host "  Flutter web caches aggressively - hard-reload the browser (Ctrl+Shift+R)"
Write-Host "  after every rebuild, or you may be testing old code." -ForegroundColor DarkGray
