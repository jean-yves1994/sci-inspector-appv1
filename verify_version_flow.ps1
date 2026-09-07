# =============================================================================
# SCI - verify the inspection version lifecycle end to end.
#
#   powershell -ExecutionPolicy Bypass -File verify_version_flow.ps1 `
#       -Email inspector@sci.rw -Password 'YOUR_PASSWORD'
#
# Read-mostly: it creates ONE property and ONE inspection, then exercises the
# save path. Point it at a non-production tenant.
#
# NOTE: authored without a PowerShell runtime available, so it is unverified.
# It only reads and creates test data - it never deletes or submits.
# =============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Password,
    [string]$BaseUrl = 'https://server.realcovenants.com/api/v1',
    [string]$Platform = 'android'   # mirrors the app's dev override
)

$ErrorActionPreference = 'Stop'
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
    $colour = switch ($Level) {
        'PASS' { 'Green' }; 'FAIL' { 'Red' }; default { 'Yellow' }
    }
    Say "   [$Level] $Text" $colour
}

function Call {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body,
        [switch]$AllowFailure
    )

    $headers = @{ 'Accept' = 'application/json' }
    if ($script:Token) { $headers['Authorization'] = "Bearer $script:Token" }

    $args = @{
        Method      = $Method
        Uri         = "$BaseUrl$Path"
        Headers     = $headers
        ContentType = 'application/json'
    }
    if ($Body) { $args['Body'] = ($Body | ConvertTo-Json -Depth 10) }

    try {
        return Invoke-RestMethod @args
    }
    catch {
        $resp = $_.Exception.Response
        $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
        $raw = ''
        if ($resp) {
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $raw = $reader.ReadToEnd()
        }
        if ($AllowFailure) {
            return [pscustomobject]@{ __status = $status; __raw = $raw }
        }
        Say "   HTTP $status on $Method $Path" 'Red'
        Say "   $raw" 'DarkGray'
        throw
    }
}

# Reads `version` wherever the API happens to put it.
function Get-Version($obj) {
    if ($null -eq $obj) { return $null }
    if ($null -ne $obj.version) { return [int]$obj.version }
    if ($null -ne $obj.data -and $null -ne $obj.data.version) {
        return [int]$obj.data.version
    }
    return $null
}

function Show-Version([string]$Label, $obj) {
    $v = Get-Version $obj
    $shown = if ($null -eq $v) { 'ABSENT' } else { $v }
    $status = if ($obj.status) { $obj.status } elseif ($obj.data.status) { $obj.data.status } else { '-' }
    Say ("   {0,-34} version={1,-8} status={2}" -f $Label, $shown, $status)
    return $v
}

# ---------------------------------------------------------------- 1. login
Step '1. Authenticate'
$login = Call -Method POST -Path '/auth/login' -Body @{
    email = $Email; password = $Password; platform = $Platform
}
$script:Token = $login.accessToken
if (-not $script:Token) { throw 'No accessToken in the login response.' }
Say "   signed in as $($login.user.email)" 'Green'

if ($login.refreshToken) {
    Finding 'PASS' "platform='$Platform' returns a refreshToken in the body"
} else {
    Finding 'WARN' "platform='$Platform' returned NO refreshToken (expected for 'web')"
}

# ------------------------------------------------------------- 2. property
Step '2. Create a property'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$property = Call -Method POST -Path '/properties' -Body @{
    name            = "Version probe $stamp"
    propertyType    = 'Commercial'
    ownerClientName = 'Version Probe'
    province        = 'Kigali'
    district        = 'Gasabo'
    sector          = 'Kimironko'
    cell            = 'Nyagatovu'
}
$propertyId = if ($property.id) { $property.id } else { $property.data.id }
Say "   property $propertyId" 'Green'

# ----------------------------------------------------------- 3. inspection
Step '3. Create an inspection'
$created = Call -Method POST -Path '/inspections' -Body @{
    propertyId    = $propertyId
    loanReference = "PROBE-$stamp"
    clientName    = 'Version Probe'
    priority      = 'NORMAL'
}
$inspectionId = if ($created.id) { $created.id } else { $created.data.id }
Say "   inspection $inspectionId" 'Green'
$vCreate = Show-Version 'POST /inspections' $created

$afterCreate = Call -Method GET -Path "/inspections/$inspectionId"
$vAfterCreate = Show-Version 'GET  /inspections/{id}' $afterCreate

if ($null -eq $vCreate) {
    Finding 'WARN' 'POST /inspections omits `version` from its response'
} elseif ($vCreate -ne $vAfterCreate) {
    Finding 'FAIL' "create returned version=$vCreate but GET says $vAfterCreate"
} else {
    Finding 'PASS' "create and GET agree on version=$vCreate"
}

# ---------------------------------------------------------------- 4. start
# THE CRITICAL CHECK. If start's response omits `version`, the Flutter parser
# stored 0 and the next PATCH sent baseVersion=0 -> 409.
Step '4. Start the inspection  <-- the suspected root cause'
$started = Call -Method POST -Path "/inspections/$inspectionId/start"
$vStart = Show-Version 'POST /inspections/{id}/start' $started

$afterStart = Call -Method GET -Path "/inspections/$inspectionId"
$vAfterStart = Show-Version 'GET  /inspections/{id}' $afterStart

if ($null -eq $vStart) {
    Finding 'FAIL' 'ROOT CAUSE: start() response has NO `version` field. The client parsed it as 0 and sent baseVersion=0 on the next save.'
} elseif ($vStart -ne $vAfterStart) {
    Finding 'FAIL' "ROOT CAUSE: start() returned version=$vStart but the record is actually at $vAfterStart."
} else {
    Finding 'PASS' "start() returns a consistent version=$vStart"
}

if ($null -ne $vAfterCreate -and $null -ne $vAfterStart) {
    if ($vAfterStart -gt $vAfterCreate) {
        Say "   start incremented the version ($vAfterCreate -> $vAfterStart)" 'DarkGray'
    } else {
        Say "   start did NOT increment the version (still $vAfterStart)" 'DarkGray'
    }
}

# ------------------------------------------------- 5. sequential mutations
Step '5. Sequential saves - each must consume the previous version'
$current = $vAfterStart

# Owner is a fixed endpoint, so it needs no template lookup.
$owner = Call -Method PATCH -Path "/inspections/$inspectionId/owner" -Body @{
    fullName    = 'Version Probe Owner'
    baseVersion = $current
}
$vOwner = Show-Version "PATCH owner (baseVersion=$current)" $owner

if ($null -eq $vOwner) {
    Finding 'FAIL' 'PATCH /owner response omits `version` - the client cannot track the lifecycle.'
} elseif ($vOwner -le $current) {
    Finding 'WARN' "PATCH /owner did not increment the version ($current -> $vOwner)"
} else {
    Finding 'PASS' "PATCH /owner incremented $current -> $vOwner"
    $current = $vOwner
}

$valuation = Call -Method PATCH -Path "/inspections/$inspectionId/valuation" -Body @{
    currency    = 'RWF'
    marketValue = 1000000
    baseVersion = $current
}
$vVal = Show-Version "PATCH valuation (baseVersion=$current)" $valuation
if ($null -ne $vVal -and $vVal -gt $current) {
    Finding 'PASS' "PATCH /valuation incremented $current -> $vVal"
    $current = $vVal
} elseif ($null -eq $vVal) {
    Finding 'FAIL' 'PATCH /valuation response omits `version`.'
}

# ------------------------------------------------------- 6. stale rejection
Step '6. A stale baseVersion must be rejected'
$stale = Call -Method PATCH -Path "/inspections/$inspectionId/owner" -AllowFailure -Body @{
    fullName    = 'Should be rejected'
    baseVersion = 0
}

if ($stale.__status -eq 409) {
    Finding 'PASS' 'baseVersion=0 correctly returns 409'
    Say "   $($stale.__raw)" 'DarkGray'
    if ($stale.__raw -match 'INSPECTION_STALE_VERSION') {
        Finding 'PASS' 'the 409 body carries code INSPECTION_STALE_VERSION'
    }
    if ($stale.__raw -match 'serverVersion') {
        Finding 'PASS' 'the 409 body carries details.serverVersion'
    } else {
        Finding 'WARN' 'the 409 body has no details.serverVersion'
    }
} elseif ($stale.__status -eq 0) {
    Finding 'FAIL' 'baseVersion=0 was ACCEPTED - optimistic concurrency is not enforced.'
} else {
    Finding 'WARN' "baseVersion=0 returned HTTP $($stale.__status), expected 409"
}

# ------------------------------------------------------ 7. concurrent races
Step '7. Two writes sharing one baseVersion - exactly one must win'
$latest = Get-Version (Call -Method GET -Path "/inspections/$inspectionId")
Say "   both jobs will send baseVersion=$latest" 'DarkGray'

$job = {
    param($url, $token, $name, $version)
    try {
        $r = Invoke-RestMethod -Method PATCH -Uri $url `
            -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } `
            -ContentType 'application/json' `
            -Body (@{ fullName = $name; baseVersion = $version } | ConvertTo-Json)
        return "OK version=$($r.version)"
    } catch {
        return "HTTP $([int]$_.Exception.Response.StatusCode)"
    }
}

$url = "$BaseUrl/inspections/$inspectionId/owner"
$a = Start-Job -ScriptBlock $job -ArgumentList $url, $script:Token, 'Racer A', $latest
$b = Start-Job -ScriptBlock $job -ArgumentList $url, $script:Token, 'Racer B', $latest
$results = @(Receive-Job -Job $a -Wait), @(Receive-Job -Job $b -Wait)
Remove-Job $a, $b -Force

Say "   A: $($results[0])" 'DarkGray'
Say "   B: $($results[1])" 'DarkGray'

$wins = ($results | Where-Object { $_ -like 'OK*' }).Count
if ($wins -eq 1) {
    Finding 'PASS' 'exactly one concurrent write succeeded - concurrency is enforced'
} elseif ($wins -eq 2) {
    Finding 'FAIL' 'BOTH concurrent writes succeeded - baseVersion is not being checked'
} else {
    Finding 'WARN' 'neither write succeeded - inspect the output above'
}

# ------------------------------------------------------------ 8. completeness
Step '8. Completeness (read-only)'
$completeness = Call -Method GET -Path "/inspections/$inspectionId/completeness"
Say "   complete=$($completeness.complete) percentage=$($completeness.percentage)"
$blocking = if ($completeness.blockingIssues) { $completeness.blockingIssues.Count } else { 0 }
Say "   blockingIssues=$blocking"

# ------------------------------------------------------------------ summary
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
foreach ($f in $script:Findings) {
    $colour = switch ($f.Level) {
        'PASS' { 'Green' }; 'FAIL' { 'Red' }; default { 'Yellow' }
    }
    Write-Host ("[{0}] {1}" -f $f.Level, $f.Text) -ForegroundColor $colour
}
Write-Host ""
Write-Host "Inspection used: $inspectionId" -ForegroundColor DarkGray
Write-Host "Property used:   $propertyId" -ForegroundColor DarkGray
