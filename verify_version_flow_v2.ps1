# =============================================================================
# SCI - inspection version lifecycle probe  (v2)
#
#   powershell -ExecutionPolicy Bypass -File verify_version_flow_v2.ps1 `
#       -Email inspector@sci.rw -Password 'YOUR_PASSWORD'
#
# v2 changes:
#   * never aborts on an HTTP error - every step runs, so one run gives the
#     complete picture (v1 stopped at the first 409)
#   * re-reads the version from GET when a mutation response omits it, so the
#     probe keeps working against the current backend
#   * reports the response SHAPE when `version` is missing, which is what
#     identifies a sub-resource being returned instead of the aggregate
#
# Creates one property and one inspection. Never deletes or submits.
# Point it at non-production data.
# =============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Password,
    [string]$BaseUrl = 'https://server.realcovenants.com/api/v1',
    [string]$Platform = 'android'
)

$script:Token = $null
$script:Findings = @()

function Say([string]$Text, [string]$Colour = 'Gray') {
    Write-Host $Text -ForegroundColor $Colour
}

function Step([string]$Text) {
    Write-Host ""
    Write-Host "== $Text" -ForegroundColor Cyan
}

function Finding([string]$Level, [string]$Text) {
    $script:Findings += [pscustomobject]@{ Level = $Level; Text = $Text }
    $colour = switch ($Level) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
    Say "   [$Level] $Text" $colour
}

# Always returns an object; never throws. Failures come back with __status.
function Call {
    param([string]$Method, [string]$Path, [object]$Body)

    $headers = @{ 'Accept' = 'application/json' }
    if ($script:Token) { $headers['Authorization'] = "Bearer $script:Token" }

    $params = @{
        Method      = $Method
        Uri         = "$BaseUrl$Path"
        Headers     = $headers
        ContentType = 'application/json'
    }
    if ($Body) { $params['Body'] = ($Body | ConvertTo-Json -Depth 10) }

    try {
        $result = Invoke-RestMethod @params
        if ($null -eq $result) { $result = [pscustomobject]@{} }
        Add-Member -InputObject $result -NotePropertyName '__status' `
            -NotePropertyValue 200 -Force -ErrorAction SilentlyContinue
        return $result
    }
    catch {
        $resp = $_.Exception.Response
        $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
        $raw = ''
        if ($resp) {
            try {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $raw = $reader.ReadToEnd()
            } catch { $raw = '' }
        }
        return [pscustomobject]@{ __status = $status; __raw = $raw }
    }
}

function Failed($obj) { return $obj.__status -ne 200 }

function Get-Version($obj) {
    if ($null -eq $obj) { return $null }
    if ($null -ne $obj.version) { return [int]$obj.version }
    if ($null -ne $obj.data -and $null -ne $obj.data.version) { return [int]$obj.data.version }
    return $null
}

# Lists the top-level keys, which is how a sub-resource reveals itself.
function Show-Shape($obj) {
    $keys = ($obj.PSObject.Properties |
        Where-Object { $_.Name -ne '__status' -and $_.Name -ne '__raw' } |
        Select-Object -ExpandProperty Name) -join ', '
    if (-not $keys) { $keys = '(empty)' }
    Say "      response keys: $keys" 'DarkGray'
}

function Show-Version([string]$Label, $obj) {
    if (Failed $obj) {
        Say ("   {0,-34} HTTP {1}" -f $Label, $obj.__status) 'Red'
        if ($obj.__raw) { Say "      $($obj.__raw)" 'DarkGray' }
        return $null
    }
    $v = Get-Version $obj
    $shown = if ($null -eq $v) { 'ABSENT' } else { $v }
    $status = if ($obj.status) { $obj.status } elseif ($obj.data.status) { $obj.data.status } else { '-' }
    Say ("   {0,-34} version={1,-8} status={2}" -f $Label, $shown, $status)
    if ($null -eq $v) { Show-Shape $obj }
    return $v
}

# ---------------------------------------------------------------- 1. login
Step '1. Authenticate'
$login = Call -Method POST -Path '/auth/login' -Body @{
    email = $Email; password = $Password; platform = $Platform
}
if (Failed $login) { Say "   login failed: HTTP $($login.__status)" 'Red'; exit 1 }
$script:Token = $login.accessToken
Say "   signed in as $($login.user.email)" 'Green'

# ------------------------------------------------------------- 2. property
Step '2. Create a property'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$property = Call -Method POST -Path '/properties' -Body @{
    name = "Version probe $stamp"; propertyType = 'Commercial'
    ownerClientName = 'Version Probe'; province = 'Kigali'
    district = 'Gasabo'; sector = 'Kimironko'; cell = 'Nyagatovu'
}
if (Failed $property) { Say "   HTTP $($property.__status)" 'Red'; exit 1 }
$propertyId = if ($property.id) { $property.id } else { $property.data.id }
Say "   property $propertyId" 'Green'

# ----------------------------------------------------------- 3. inspection
Step '3. Create an inspection'
$created = Call -Method POST -Path '/inspections' -Body @{
    propertyId = $propertyId; loanReference = "PROBE-$stamp"
    clientName = 'Version Probe'; priority = 'NORMAL'
}
if (Failed $created) { Say "   HTTP $($created.__status)" 'Red'; exit 1 }
$inspectionId = if ($created.id) { $created.id } else { $created.data.id }
Say "   inspection $inspectionId" 'Green'
Show-Version 'POST /inspections' $created | Out-Null

# ---------------------------------------------------------------- 4. start
Step '4. Start the inspection'
$started = Call -Method POST -Path "/inspections/$inspectionId/start"
$vStart = Show-Version 'POST /start' $started
$vAfterStart = Show-Version 'GET  /inspections/{id}' (Call -Method GET -Path "/inspections/$inspectionId")

if ($null -eq $vStart) {
    Finding 'FAIL' 'start() response omits `version`'
} elseif ($vStart -ne $vAfterStart) {
    Finding 'FAIL' "start() said version=$vStart but the record is at $vAfterStart"
} else {
    Finding 'PASS' "start() returns a consistent version=$vStart"
}

# ------------------------------------------- 5. mutations return the version
Step '5. Do mutation responses carry the new version?'
$current = $vAfterStart

# Helper: run a mutation, then reconcile from GET so the probe can continue
# even when the response omits `version`.
function Test-Mutation {
    param([string]$Label, [string]$Method, [string]$Path, [hashtable]$Body)

    $Body['baseVersion'] = $script:current
    $result = Call -Method $Method -Path $Path -Body $Body

    if (Failed $result) {
        Say ("   {0,-34} HTTP {1}" -f $Label, $result.__status) 'Red'
        if ($result.__raw) { Say "      $($result.__raw)" 'DarkGray' }
        Finding 'FAIL' "$Label rejected with HTTP $($result.__status)"
    } else {
        $returned = Show-Version "$Label (sent base=$script:current)" $result
        if ($null -eq $returned) {
            Finding 'FAIL' "$Label response omits ``version`` - it is returning a sub-resource, not the inspection aggregate"
        } elseif ($returned -le $script:current) {
            Finding 'WARN' "$Label returned version=$returned, not greater than $script:current"
        } else {
            Finding 'PASS' "$Label incremented $script:current -> $returned"
        }
    }

    # Re-read authoritatively so the next step uses the real version.
    $fresh = Get-Version (Call -Method GET -Path "/inspections/$inspectionId")
    if ($null -ne $fresh) {
        if ($fresh -ne $script:current) {
            Say "      server is now at version $fresh" 'DarkGray'
        }
        $script:current = $fresh
    }
}

Test-Mutation 'PATCH /owner' 'PATCH' "/inspections/$inspectionId/owner" `
    @{ fullName = 'Version Probe Owner' }

Test-Mutation 'PATCH /valuation' 'PATCH' "/inspections/$inspectionId/valuation" `
    @{ currency = 'RWF'; marketValue = 1000000 }

Test-Mutation 'POST /location' 'POST' "/inspections/$inspectionId/location" `
    @{ latitude = -1.9441; longitude = 30.0619; accuracyM = 8.5; source = 'GPS'
       isMocked = $false; capturedAt = (Get-Date).ToUniversalTime().ToString('o') }

# ------------------------------------------------------- 6. stale rejection
Step '6. A stale baseVersion must be rejected'
$stale = Call -Method PATCH -Path "/inspections/$inspectionId/owner" `
    -Body @{ fullName = 'Should be rejected'; baseVersion = 0 }

if ($stale.__status -eq 409) {
    Finding 'PASS' 'baseVersion=0 correctly returns 409'
    if ($stale.__raw -match 'INSPECTION_STALE_VERSION') {
        Finding 'PASS' 'the 409 carries code INSPECTION_STALE_VERSION'
    }
    if ($stale.__raw -match 'serverVersion') {
        Finding 'PASS' 'the 409 carries details.serverVersion'
    } else {
        Finding 'WARN' 'the 409 has no details.serverVersion'
    }
} elseif ($stale.__status -eq 200) {
    Finding 'FAIL' 'baseVersion=0 was ACCEPTED - optimistic concurrency is NOT enforced'
} else {
    Finding 'WARN' "baseVersion=0 returned HTTP $($stale.__status), expected 409"
}

# ------------------------------------------------------ 7. concurrent races
Step '7. Two writes at the same version - exactly one must win'
$latest = Get-Version (Call -Method GET -Path "/inspections/$inspectionId")
Say "   both jobs send baseVersion=$latest" 'DarkGray'

$job = {
    param($url, $token, $name, $version)
    try {
        $r = Invoke-RestMethod -Method PATCH -Uri $url `
            -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } `
            -ContentType 'application/json' `
            -Body (@{ fullName = $name; baseVersion = $version } | ConvertTo-Json)
        return 'OK'
    } catch {
        return "HTTP $([int]$_.Exception.Response.StatusCode)"
    }
}

$url = "$BaseUrl/inspections/$inspectionId/owner"
$a = Start-Job -ScriptBlock $job -ArgumentList $url, $script:Token, 'Racer A', $latest
$b = Start-Job -ScriptBlock $job -ArgumentList $url, $script:Token, 'Racer B', $latest
$ra = Receive-Job -Job $a -Wait
$rb = Receive-Job -Job $b -Wait
Remove-Job $a, $b -Force

Say "   A: $ra" 'DarkGray'
Say "   B: $rb" 'DarkGray'

$wins = @($ra, $rb | Where-Object { $_ -eq 'OK' }).Count
if ($wins -eq 1) {
    Finding 'PASS' 'exactly one concurrent write succeeded'
} elseif ($wins -eq 2) {
    Finding 'FAIL' 'BOTH concurrent writes succeeded - baseVersion is not enforced, writes can be lost'
} else {
    Finding 'WARN' 'neither write succeeded'
}

# ---------------------------------------------------------- 8. completeness
Step '8. Completeness (read-only)'
$c = Call -Method GET -Path "/inspections/$inspectionId/completeness"
if (Failed $c) {
    Finding 'WARN' "completeness returned HTTP $($c.__status)"
} else {
    Say "   complete=$($c.complete)  percentage=$($c.percentage)"
    $blocking = if ($c.blockingIssues) { @($c.blockingIssues).Count } else { 0 }
    Say "   blockingIssues=$blocking"
    if ($blocking -gt 0) {
        foreach ($i in @($c.blockingIssues) | Select-Object -First 8) {
            Say "     - $($i.code) $($i.sectionCode) $($i.message)" 'DarkGray'
        }
    }
}

# ------------------------------------------------------------------ summary
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
foreach ($f in $script:Findings) {
    $colour = switch ($f.Level) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
    Write-Host ("[{0}] {1}" -f $f.Level, $f.Text) -ForegroundColor $colour
}
Write-Host ""
Write-Host "inspection: $inspectionId" -ForegroundColor DarkGray
Write-Host "property:   $propertyId" -ForegroundColor DarkGray
