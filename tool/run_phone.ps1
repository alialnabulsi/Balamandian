param(
    [string]$DeviceId,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'dev-config.json'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Create the ignored dev-config.json with API_BASE_URL and your public MAPBOX_ACCESS_TOKEN first.'
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$apiUri = [uri]$config.API_BASE_URL
if (-not $apiUri.IsAbsoluteUri -or $apiUri.Scheme -ne 'http' -or
    $apiUri.Host -ne '127.0.0.1' -or $apiUri.AbsolutePath -ne '/' -or
    $apiUri.UserInfo -or $apiUri.Query -or $apiUri.Fragment) {
    throw 'For USB development, set API_BASE_URL to http://127.0.0.1:<backend-port> in dev-config.json.'
}

$deviceOutput = & adb devices
if ($LASTEXITCODE -ne 0) { throw 'adb could not list devices.' }
$readyDevices = @($deviceOutput | ForEach-Object {
    if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
})
if (-not $DeviceId) {
    if ($readyDevices.Count -ne 1) {
        throw 'Connect and authorize one Android phone, or pass -DeviceId <serial>.'
    }
    $DeviceId = $readyDevices[0]
}
if ($DeviceId -notin $readyDevices) {
    throw "Device $DeviceId is not connected and authorized. Check adb devices."
}

try {
    $health = Invoke-RestMethod -Uri ([uri]::new($apiUri, '/health')) -TimeoutSec 5
    if ($health.status -ne 'ok') { throw 'Unexpected health response.' }
} catch {
    throw "Backend is unavailable at $($apiUri.GetLeftPart([System.UriPartial]::Authority)). Start Balamandian-API with npm run dev in another terminal."
}

$portMapping = 'tcp:' + $apiUri.Port
& adb -s $DeviceId reverse $portMapping $portMapping
if ($LASTEXITCODE -ne 0) { throw 'Could not forward the backend port over USB.' }
Write-Host "Device: $DeviceId"
Write-Host "API: $($apiUri.GetLeftPart([System.UriPartial]::Authority)) (healthy; USB forwarding configured)"
Write-Host 'Using dev-config.json for API and Mapbox settings.'
if ($CheckOnly) { return }

Push-Location $projectRoot
try {
    & flutter run -d $DeviceId --dart-define-from-file=dev-config.json
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
