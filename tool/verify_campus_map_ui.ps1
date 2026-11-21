param(
  [string]$Flutter = 'flutter',
  [string]$Adb = 'adb',
  [string]$Device = 'RZCW807CGEW',
  [string]$Defines = 'config/mapbox.local.json',
  [switch]$Interactions,
  [switch]$SkipRestore
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $workspace
$output = Join-Path $workspace $(if ($Interactions) { 'build/map-refinement/device-final' } else { 'build/map-refinement/device' })
$log = Join-Path $workspace 'build/map-refinement/ui-native.log'
New-Item -ItemType Directory -Path $output -Force | Out-Null
Set-Content -LiteralPath $log -Value ''
function Invoke-FlutterCheck {
  param([string[]]$FlutterArguments, [string]$LogPath)
  # Windows PowerShell can treat harmless native stderr as a terminating error.
  # Preserve that output in the ignored log and use the process exit code.
  $ErrorActionPreference = 'Continue'
  & $Flutter @FlutterArguments *> $LogPath
  return $LASTEXITCODE
}
# Capture the real display: SDK snapshots exclude Flutter and legal ornaments.
$capture = Start-Job -ArgumentList $log, $output, $Adb, $Device -ScriptBlock {
  param($logPath, $outputPath, $adbCommand, $serial)
  $captured = @{}
  $nativePan = $false
  $nativeAttribution = $false
  function Test-MapForeground {
    $focus = & $adbCommand -s $serial shell dumpsys window | Select-String 'mCurrentFocus'
    return [bool]($focus -match 'com\.example\.balamandian')
  }
  $deadline = (Get-Date).AddMinutes(8)
  while ((Get-Date) -lt $deadline) {
    $tail = Get-Content -LiteralPath $logPath -Tail 100 -ErrorAction SilentlyContinue
    foreach ($line in $tail) {
      if (-not $nativePan -and $line -match 'MAP_UI_NATIVE_PAN (\d+) (\d+) (\d+) (\d+)') {
        $coordinates = @($Matches[1], $Matches[2], $Matches[3], $Matches[4])
        if (Test-MapForeground) {
          & $adbCommand -s $serial shell input swipe @coordinates 500
          $nativePan = $true
        }
      }
      if (-not $nativeAttribution -and $line -match 'MAP_UI_NATIVE_ATTRIBUTION (\d+) (\d+)') {
        $coordinates = @($Matches[1], $Matches[2])
        if (Test-MapForeground) {
          & $adbCommand -s $serial shell input tap @coordinates
          $nativeAttribution = $true
        }
      }
      if ($line -match 'MAP_UI_CAPTURE ([a-zA-Z0-9-]+)') {
        $stage = $Matches[1]
        if (-not $captured.ContainsKey($stage)) {
          if (-not (Test-MapForeground)) { continue }
          & $adbCommand -s $serial shell screencap -p /data/local/tmp/balamandian-map-ui.png | Out-Null
          & $adbCommand -s $serial pull /data/local/tmp/balamandian-map-ui.png (Join-Path $outputPath "$stage.png") 2>&1 | Out-Null
          if ($stage -eq '18-attribution-dialog') {
            & $adbCommand -s $serial shell uiautomator dump /data/local/tmp/balamandian-map-legal.xml 2>&1 | Out-Null
            & $adbCommand -s $serial pull /data/local/tmp/balamandian-map-legal.xml (Join-Path $outputPath 'attribution.xml') 2>&1 | Out-Null
            & $adbCommand -s $serial shell input keyevent 4
          }
          $captured[$stage] = $true
          Write-Output "Captured $stage"
        }
      }
    }
    if ($tail -match 'All tests passed|Some tests failed|FAILURE:|Exception: Gradle task') { break }
    Start-Sleep -Milliseconds 200
  }
}
$nativeExit = 1
try {
  $driver = if ($Interactions) { 'test_driver/campus_map_interaction.dart' } else { 'test_driver/campus_map_ui.dart' }
  $driveArguments = @('drive', '--no-pub', "--driver=$driver", '--target=integration_test/campus_map_ui_test.dart', '-d', $Device, "--dart-define-from-file=$Defines")
  if ($Interactions) { $driveArguments += '--dart-define=CAMPUS_INTERACTION_SMOKE=true' }
  $nativeExit = Invoke-FlutterCheck -FlutterArguments $driveArguments -LogPath $log
} finally {
  $capture | Wait-Job -Timeout 5 | Out-Null
  if ($capture.State -eq 'Running') { Stop-Job -Job $capture }
  Receive-Job -Job $capture
  Remove-Job -Job $capture
  if (-not $SkipRestore) {
    $restoreLog = Join-Path $workspace 'build/map-refinement/restore.log'
    $restoreExit = Invoke-FlutterCheck -FlutterArguments @('build', 'apk', '--no-pub', '--debug', '--target=lib/main.dart', '--target-platform=android-arm64', "--dart-define-from-file=$Defines") -LogPath $restoreLog
    if ($restoreExit -eq 0) {
      $ErrorActionPreference = 'Continue'
      & $Adb -s $Device install -r build/app/outputs/flutter-apk/app-debug.apk
      & $Adb -s $Device shell am start -n com.example.balamandian/.MainActivity
      $ErrorActionPreference = 'Stop'
    } else {
      Write-Warning 'Normal app build failed; see build/map-refinement/restore.log.'
    }
  }
}
if ($nativeExit -ne 0) { throw 'Native UI verification failed; see build/map-refinement/ui-native.log.' }
Write-Output "Native UI verification passed. Screenshots and metrics: $output."
