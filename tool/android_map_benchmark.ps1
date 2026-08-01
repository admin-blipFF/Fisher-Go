param(
  [string]$DeviceSerial,
  [int]$MinimumApi = 35,
  [string]$Variant = 'installed-profile',
  [string]$ApkPath = 'build/app/outputs/flutter-apk/app-profile.apk',
  [int]$SwipeDurationMs = 350,
  [int]$PauseMs = 450,
  [int]$WarmupRounds = 0,
  [switch]$SkipInstall,
  [switch]$RequireHostGpu,
  [switch]$RequireMapReadiness,
  [switch]$AllowHudlessGameHome,
  [int]$MaxP95Ms = 20,
  [int]$MinimumFrameCount = 60,
  [switch]$EnforceFrameBudget,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if ($null -ne $adbCommand) {
  $adbPath = $adbCommand.Source
} else {
  $adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (-not (Test-Path $adbPath)) {
    throw 'adb was not found. Install Android platform-tools or add adb to PATH.'
  }
}

$preflight = Join-Path $PSScriptRoot 'android_smoke_preflight.ps1'
$preflightArgs = @('-ExecutionPolicy', 'Bypass', '-File', $preflight, '-MinimumApi', $MinimumApi)
if ($DeviceSerial) {
  $preflightArgs += @('-DeviceSerial', $DeviceSerial)
}
$preflightOutput = & powershell @preflightArgs
$selectedLine = $preflightOutput | Where-Object { $_ -match '^ANDROID_SMOKE_DEVICE=' } | Select-Object -First 1
if (-not $selectedLine) {
  throw 'Android preflight did not select a device.'
}
$serial = ($selectedLine -split '=', 2)[1]

$surfaceFlingerText = (& $adbPath -s $serial shell dumpsys SurfaceFlinger 2>$null | Out-String)
$gpuRenderer = (
  $surfaceFlingerText -split "`r?`n" |
    Where-Object { $_ -match '^GLES:' } |
    Select-Object -First 1
).Trim()
Write-Output "ANDROID_GPU_RENDERER=$gpuRenderer"
if ($RequireHostGpu -and
    ([string]::IsNullOrWhiteSpace($gpuRenderer) -or
      $gpuRenderer -match 'SwiftShader|llvmpipe|software')) {
  throw "Host GPU rendering is required, but the emulator reported '$gpuRenderer'. Launch the API 35 AVD with -gpu host."
}

if (-not $SkipInstall -and -not (Test-Path $ApkPath)) {
  throw "APK not found at '$ApkPath'. Build the profile proof APK before benchmarking."
}
if ($SkipInstall) {
  $installedPackage = (& $adbPath -s $serial shell pm path com.fishergo.app | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($installedPackage)) {
    throw 'com.fishergo.app is not installed; run without -SkipInstall first.'
  }
} else {
  & $adbPath -s $serial uninstall com.fishergo.app | Out-Null
  & $adbPath -s $serial install $ApkPath | Out-Null
}

# Benchmarks must start on the game surface, not an Android permission dialog.
# Grant the app's runtime permissions after every clean install so the gesture
# sequence measures map rendering rather than startup permission sequencing.
$benchmarkPermissions = @(
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.READ_MEDIA_IMAGES',
  'android.permission.READ_MEDIA_VISUAL_USER_SELECTED'
)
foreach ($permission in $benchmarkPermissions) {
  & $adbPath -s $serial shell pm grant com.fishergo.app $permission 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not grant benchmark permission '$permission'; continuing."
  }
}

if ($serial -like 'emulator-*') {
  & $adbPath -s $serial shell settings put secure location_mode 3 | Out-Null
  & $adbPath -s $serial emu geo fix 114.1874 22.3819 | Out-Null
}

& $adbPath -s $serial logcat -c
& $adbPath -s $serial shell am force-stop com.fishergo.app | Out-Null
& $adbPath -s $serial shell monkey -p com.fishergo.app 1 | Out-Null
Start-Sleep -Seconds 12

$appPid = ((& $adbPath -s $serial shell pidof com.fishergo.app | Out-String).Trim())
if (-not $appPid) {
  throw "com.fishergo.app did not stay running on $serial."
}

function Get-BenchmarkUiXml {
  $dumpPath = '/sdcard/fishergo-benchmark-ui.xml'
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    for ($uiautomator_retry_count = 0; $uiautomator_retry_count -lt 4; $uiautomator_retry_count++) {
      $dumpOutput = (& $adbPath -s $serial shell uiautomator dump $dumpPath 2>&1 | Out-String)
      if ($dumpOutput -match 'null root|ERROR') {
        Start-Sleep -Milliseconds 300
        continue
      }
      $xml = (& $adbPath -s $serial shell cat $dumpPath | Out-String).Trim()
      if ([string]::IsNullOrWhiteSpace($xml)) {
        Start-Sleep -Milliseconds 300
        continue
      }
      return $xml -replace "`r?`n", ''
    }
    return ''
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Tap-BenchmarkControl([string]$UiXml, [string]$ContentDescription) {
  $escapedDescription = [regex]::Escape($ContentDescription)
  $pattern = 'content-desc="' + $escapedDescription + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $match = [regex]::Match($UiXml, $pattern)
  if (-not $match.Success) { return $false }

  $left = [int]$match.Groups[1].Value
  $top = [int]$match.Groups[2].Value
  $right = [int]$match.Groups[3].Value
  $bottom = [int]$match.Groups[4].Value
  $x = [math]::Floor(($left + $right) / 2)
  $y = [math]::Floor(($top + $bottom) / 2)
  & $adbPath -s $serial shell input tap $x $y | Out-Null
  return $true
}

$gameHomeReady = $false
for ($attempt = 0; $attempt -lt 12; $attempt++) {
  $uiXml = Get-BenchmarkUiXml
  if ($uiXml -match 'content-desc="訪客遊玩"') {
    if (Tap-BenchmarkControl $uiXml '訪客遊玩') {
      Start-Sleep -Seconds 2
      continue
    }
  }
  if ($uiXml -match 'content-desc="略過"') {
    if (Tap-BenchmarkControl $uiXml '略過') {
      Start-Sleep -Seconds 2
      continue
    }
  }
  if ($uiXml -match 'content-desc="Fisher Lv\. 1"') {
    $gameHomeReady = $true
    break
  }
  if ($AllowHudlessGameHome -and
      $uiXml -match 'Showing a Map created with MapLibre') {
    $gameHomeReady = $true
    break
  }
  Start-Sleep -Seconds 1
}
if (-not $gameHomeReady) {
  throw 'Benchmark did not reach the FisherGO GameHome surface after startup.'
}

# Location is an explicit player action in production. Trigger it before the
# gesture trace so a clean benchmark measures the GPS-centered map surface.
$locationRequested = $false
$locationDescription = $null
for ($locationAttempt = 0; $locationAttempt -lt 8; $locationAttempt++) {
  $locationUiXml = Get-BenchmarkUiXml
  if ($locationUiXml -match 'content-desc="重新定位"') {
    if (Tap-BenchmarkControl $locationUiXml '重新定位') {
      $locationRequested = $true
      break
    }
  }
  # A valid emulator fix changes the same production control's label to its
  # accuracy (for example, "GPS 15m"). It remains the explicit recenter
  # action, so accept that semantic state as well.
  $gpsDescriptionMatch = [regex]::Match(
    $locationUiXml,
    'content-desc="(GPS [^"]+)"'
  )
  if ($gpsDescriptionMatch.Success) {
    $locationDescription = $gpsDescriptionMatch.Groups[1].Value
    if (Tap-BenchmarkControl $locationUiXml $locationDescription) {
      $locationRequested = $true
      break
    }
  }
  Start-Sleep -Milliseconds 500
}
if (-not $locationRequested) {
  throw 'Benchmark could not trigger the explicit FisherGO location action.'
}
Start-Sleep -Seconds 3

$mapReadinessObserved = $false
if ($RequireMapReadiness) {
  for ($readinessAttempt = 0; $readinessAttempt -lt 30; $readinessAttempt++) {
    $readinessLog = (& $adbPath -s $serial logcat -d -t 5000 | Out-String)
    if ($readinessLog -match 'FisherGO map readiness:') {
      $mapReadinessObserved = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $mapReadinessObserved) {
    throw 'Map readiness telemetry was required but not observed. Build with FISHERGO_MAP_PERF=true before using this gate.'
  }
} else {
  $readinessLog = (& $adbPath -s $serial logcat -d -t 5000 | Out-String)
  $mapReadinessObserved = $readinessLog -match 'FisherGO map readiness:'
}

$swipes = @(
  @(300, 700, 800, 700),
  @(800, 700, 300, 700),
  @(340, 850, 760, 1250),
  @(760, 1250, 340, 850),
  @(300, 1100, 820, 1100),
  @(820, 1100, 300, 1100),
  @(450, 650, 450, 1600),
  @(450, 1600, 450, 650),
  @(750, 650, 350, 1550),
  @(350, 1550, 750, 650),
  @(320, 900, 800, 1400),
  @(800, 1400, 320, 900)
)

for ($round = 0; $round -lt $WarmupRounds; $round++) {
  foreach ($swipe in $swipes) {
    & $adbPath -s $serial shell input swipe $swipe[0] $swipe[1] $swipe[2] $swipe[3] $SwipeDurationMs | Out-Null
    Start-Sleep -Milliseconds $PauseMs
  }
}

& $adbPath -s $serial shell dumpsys gfxinfo com.fishergo.app reset | Out-Null

foreach ($swipe in $swipes) {
  & $adbPath -s $serial shell input swipe $swipe[0] $swipe[1] $swipe[2] $swipe[3] $SwipeDurationMs | Out-Null
  Start-Sleep -Milliseconds $PauseMs
}
Start-Sleep -Seconds 2

$gfxText = (& $adbPath -s $serial shell dumpsys gfxinfo com.fishergo.app | Out-String)
$logText = (& $adbPath -s $serial logcat -d -t 5000 | Out-String)
$activityProcessText = (& $adbPath -s $serial shell dumpsys activity processes com.fishergo.app | Out-String)
$anrDetected = $activityProcessText -match 'mNotResponding=true'
$telemetryLines = @(
  $logText -split "`r?`n" |
    Where-Object { $_ -match 'FisherGO (map|fallback) performance:' } |
    Select-Object -Last 5
)
$telemetryText = $telemetryLines -join "`n"
$readinessLines = @(
  $logText -split "`r?`n" |
    Where-Object { $_ -match 'FisherGO map readiness:' } |
    Select-Object -Last 5
)
$readinessText = $readinessLines -join "`n"

function Get-IntMetric([string]$Pattern) {
  $match = [regex]::Match($gfxText, $Pattern)
  if (-not $match.Success) { return $null }
  return [int]$match.Groups[1].Value
}

function Get-DoubleMetric([string]$Pattern) {
  $match = [regex]::Match($gfxText, $Pattern)
  if (-not $match.Success) { return $null }
  return [double]$match.Groups[1].Value
}

function Get-TelemetryIntMetric([string]$Pattern) {
  $matches = [regex]::Matches($telemetryText, $Pattern)
  if ($matches.Count -eq 0) { return $null }
  return [int]$matches[$matches.Count - 1].Groups[1].Value
}

function Get-TelemetryDoubleMetric([string]$Pattern) {
  $matches = [regex]::Matches($telemetryText, $Pattern)
  if ($matches.Count -eq 0) { return $null }
  return [double]$matches[$matches.Count - 1].Groups[1].Value
}

function Get-ReadinessIntMetric([string]$Pattern) {
  $matches = [regex]::Matches($readinessText, $Pattern)
  if ($matches.Count -eq 0) { return $null }
  return [int]$matches[$matches.Count - 1].Groups[1].Value
}

$totalFrames = Get-IntMetric 'Total frames rendered:\s+(\d+)'
$gfxTraceValid = $null -ne $totalFrames -and $totalFrames -ge $MinimumFrameCount
$p95Ms = if ($gfxTraceValid) {
  Get-IntMetric '95th percentile:\s+(\d+)ms'
} else {
  $null
}
$frameBudgetPassed = if ($null -eq $p95Ms) {
  $null
} else {
  $p95Ms -le $MaxP95Ms
}

$result = [ordered]@{
  timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
  variant = $Variant
  device = $serial
  minimum_api = $MinimumApi
  warmup_rounds = $WarmupRounds
  skip_install = [bool]$SkipInstall
  require_host_gpu = [bool]$RequireHostGpu
  require_map_readiness = [bool]$RequireMapReadiness
  allow_hudless_game_home = [bool]$AllowHudlessGameHome
  map_readiness_observed = [bool]$mapReadinessObserved
  gpu_renderer = $gpuRenderer
  package = 'com.fishergo.app'
  gfx_trace_valid = [bool]$gfxTraceValid
  total_frames = $totalFrames
  janky_frames = if ($gfxTraceValid) { Get-IntMetric 'Janky frames:\s+(\d+)' } else { $null }
  janky_percent = if ($gfxTraceValid) { Get-DoubleMetric 'Janky frames:\s+\d+\s+\(([\d.]+)%\)' } else { $null }
  p50_ms = if ($gfxTraceValid) { Get-IntMetric '50th percentile:\s+(\d+)ms' } else { $null }
  p90_ms = if ($gfxTraceValid) { Get-IntMetric '90th percentile:\s+(\d+)ms' } else { $null }
  p95_ms = $p95Ms
  max_p95_ms = $MaxP95Ms
  minimum_frame_count = $MinimumFrameCount
  enforce_frame_budget = [bool]$EnforceFrameBudget
  frame_budget_passed = $frameBudgetPassed
  p99_ms = if ($gfxTraceValid) { Get-IntMetric '99th percentile:\s+(\d+)ms' } else { $null }
  slow_ui_thread = if ($gfxTraceValid) { Get-IntMetric 'Number Slow UI thread:\s+(\d+)' } else { $null }
  slow_bitmap_uploads = if ($gfxTraceValid) { Get-IntMetric 'Number Slow bitmap uploads:\s+(\d+)' } else { $null }
  slow_draw_commands = if ($gfxTraceValid) { Get-IntMetric 'Number Slow issue draw commands:\s+(\d+)' } else { $null }
  flutter_frame_count = Get-TelemetryIntMetric 'frame_count:\s+(\d+)'
  flutter_p50_build_ms = Get-TelemetryIntMetric 'p50_build_ms:\s+(\d+)'
  flutter_p95_build_ms = Get-TelemetryIntMetric 'p95_build_ms:\s+(\d+)'
  flutter_p50_raster_ms = Get-TelemetryIntMetric 'p50_raster_ms:\s+(\d+)'
  flutter_p95_raster_ms = Get-TelemetryIntMetric 'p95_raster_ms:\s+(\d+)'
  flutter_p50_total_ms = Get-TelemetryIntMetric 'p50_total_ms:\s+(\d+)'
  flutter_p95_total_ms = Get-TelemetryIntMetric 'p95_total_ms:\s+(\d+)'
  flutter_p50_vsync_overhead_ms = Get-TelemetryIntMetric 'p50_vsync_overhead_ms:\s+(\d+)'
  flutter_p95_vsync_overhead_ms = Get-TelemetryIntMetric 'p95_vsync_overhead_ms:\s+(\d+)'
  flutter_p50_frame_gap_ms = Get-TelemetryIntMetric 'p50_frame_gap_ms:\s+(\d+)'
  flutter_p95_frame_gap_ms = Get-TelemetryIntMetric 'p95_frame_gap_ms:\s+(\d+)'
  flutter_janky_frames = Get-TelemetryIntMetric 'janky_frames:\s+(\d+)'
  flutter_janky_rate = Get-TelemetryDoubleMetric 'janky_rate:\s+([\d.]+)'
  readiness_style_ready_ms = Get-ReadinessIntMetric 'style_ready_ms:\s+(\d+)'
  readiness_map_idle_ms = Get-ReadinessIntMetric 'map_idle_ms:\s+(\d+)'
  anr_detected = [bool]$anrDetected
  telemetry = $telemetryLines
  readiness_telemetry = $readinessLines
}

$json = [pscustomobject]$result | ConvertTo-Json -Depth 5
if ($OutputPath) {
  $parent = Split-Path -Parent $OutputPath
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Set-Content -Path $OutputPath -Value $json -Encoding utf8
}

Write-Output $json
if ($anrDetected) {
  throw "Android map benchmark detected an application-not-responding state on $serial."
}
if (-not $gfxTraceValid) {
  throw "Android map benchmark did not produce a valid gfxinfo frame trace with the minimum frame count on $serial. Check platform-view composition before comparing performance."
}
if ($EnforceFrameBudget -and $null -eq $p95Ms) {
  throw "Frame budget gate requires a p95 metric on ${serial}."
}
if ($EnforceFrameBudget -and $frameBudgetPassed -eq $false) {
  throw "Frame budget exceeded on ${serial}: p95 ${p95Ms}ms > max ${MaxP95Ms}ms."
}
