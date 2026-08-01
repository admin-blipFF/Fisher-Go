param(
  [string]$DeviceSerial,
  [int]$MinimumApi = 35,
  [string]$Variant = 'native-maplibre-surface',
  [string]$ApkPath = 'build/app/outputs/flutter-apk/app-profile.apk',
  [int]$SwipeDurationMs = 350,
  [int]$PauseMs = 450,
  [int]$WarmupRounds = 1,
  [switch]$SkipInstall,
  [switch]$RequireHostGpu,
  [switch]$DisableTilePrefetch,
  [switch]$DisableBuildingExtrusion,
  [switch]$DisableLandcover,
  [switch]$DisableFillAntialias,
  [switch]$DisableRoads,
  [switch]$DisableWater,
  [switch]$DisableWaterOutline,
  [switch]$DisableWaterway,
  [switch]$DisablePier,
  [switch]$WhenDirtyRefresh,
  [int]$MaxP95Ms = 20,
  [int]$MinimumFrameCount = 60,
  [switch]$EnforceFrameBudget,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.fishergo.app'
$activityName = "$packageName/.NativeMapProofActivity"

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
  $installedPackage = (& $adbPath -s $serial shell pm path $packageName | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($installedPackage)) {
    throw "$packageName is not installed; run without -SkipInstall first."
  }
} else {
  & $adbPath -s $serial uninstall $packageName | Out-Null
  & $adbPath -s $serial install $ApkPath | Out-Null
}

if ($serial -like 'emulator-*') {
  & $adbPath -s $serial shell settings put secure location_mode 3 | Out-Null
  & $adbPath -s $serial emu geo fix 114.1874 22.3819 | Out-Null
}

& $adbPath -s $serial logcat -c
& $adbPath -s $serial shell am force-stop $packageName | Out-Null
$activityIntentArgs = @()
if ($DisableTilePrefetch) {
  $activityIntentArgs += @('--ez', 'noTilePrefetch', 'true')
}
if ($DisableBuildingExtrusion) {
  $activityIntentArgs += @('--ez', 'noBuildingExtrusion', 'true')
}
if ($DisableLandcover) {
  $activityIntentArgs += @('--ez', 'noLandcover', 'true')
}
if ($DisableFillAntialias) {
  $activityIntentArgs += @('--ez', 'noFillAntialias', 'true')
}
if ($DisableRoads) {
  $activityIntentArgs += @('--ez', 'noRoads', 'true')
}
if ($DisableWater) {
  $activityIntentArgs += @('--ez', 'noWater', 'true')
}
if ($DisableWaterOutline) {
  $activityIntentArgs += @('--ez', 'noWaterOutline', 'true')
}
if ($DisableWaterway) {
  $activityIntentArgs += @('--ez', 'noWaterway', 'true')
}
if ($DisablePier) {
  $activityIntentArgs += @('--ez', 'noPier', 'true')
}
if ($WhenDirtyRefresh) {
  $activityIntentArgs += @('--ez', 'whenDirtyRefresh', 'true')
}
& $adbPath -s $serial shell am start -n $activityName @activityIntentArgs | Out-Null
Start-Sleep -Seconds 12

$appPid = ((& $adbPath -s $serial shell pidof $packageName | Out-String).Trim())
if (-not $appPid) {
  throw "$activityName did not stay running on $serial."
}

function Get-ProofUiXml {
  $dumpPath = '/sdcard/fishergo-native-map-proof.xml'
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    for ($retry = 0; $retry -lt 5; $retry++) {
      $dumpOutput = (& $adbPath -s $serial shell uiautomator dump $dumpPath 2>&1 | Out-String)
      if ($dumpOutput -match 'null root|ERROR') {
        Start-Sleep -Milliseconds 300
        continue
      }
      $xml = (& $adbPath -s $serial shell cat $dumpPath | Out-String).Trim()
      if (-not [string]::IsNullOrWhiteSpace($xml)) {
        return $xml -replace "`r?`n", ''
      }
      Start-Sleep -Milliseconds 300
    }
    return ''
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

$uiXml = Get-ProofUiXml
if ($uiXml -notmatch 'Native MapLibre surface proof') {
  throw 'Native MapLibre proof label was not found; the isolated activity did not reach a usable UI state.'
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

# A direct MapView uses its own BLAST SurfaceView, so gfxinfo intentionally
# reports zero Flutter/UI frames. SurfaceFlinger timestats measures the actual
# native map surface after composition and exposes present-to-present buckets.
& $adbPath -s $serial shell dumpsys SurfaceFlinger --timestats -clear -enable | Out-Null
foreach ($swipe in $swipes) {
  & $adbPath -s $serial shell input swipe $swipe[0] $swipe[1] $swipe[2] $swipe[3] $SwipeDurationMs | Out-Null
  Start-Sleep -Milliseconds $PauseMs
}
Start-Sleep -Seconds 2

$timestatsText = (& $adbPath -s $serial shell dumpsys SurfaceFlinger --timestats -dump | Out-String)
& $adbPath -s $serial shell dumpsys SurfaceFlinger --timestats -disable | Out-Null
$activityProcessText = (& $adbPath -s $serial shell dumpsys activity processes $packageName | Out-String)
$anrDetected = $activityProcessText -match 'mNotResponding=true'

$layerPattern = 'layerName = SurfaceView\[' +
  [regex]::Escape("$packageName/$packageName.NativeMapProofActivity") +
  '\]\(BLAST\)#\d+(?<block>.*?)(?=\r?\n\s*layerName = |\z)'
$layerMatch = [regex]::Match($timestatsText, $layerPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$layerText = if ($layerMatch.Success) { $layerMatch.Groups['block'].Value } else { '' }

function Get-LayerIntMetric([string]$Pattern) {
  $match = [regex]::Match($layerText, $Pattern)
  if (-not $match.Success) { return $null }
  return [int]$match.Groups[1].Value
}

function Get-LayerDoubleMetric([string]$Pattern) {
  $match = [regex]::Match($layerText, $Pattern)
  if (-not $match.Success) { return $null }
  return [double]$match.Groups[1].Value
}

$histogramMatch = [regex]::Match(
  $layerText,
  'present2present histogram is as below:\s*(?<hist>.*?)(?=\r?\n\s*latch2present histogram|\z)',
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$histogram = if ($histogramMatch.Success) { $histogramMatch.Groups['hist'].Value } else { '' }
$histogramBuckets = @(
  [regex]::Matches($histogram, '(\d+)ms=(\d+)') |
    ForEach-Object {
      [pscustomobject]@{
        milliseconds = [int]$_.Groups[1].Value
        count = [int]$_.Groups[2].Value
      }
    } |
    Where-Object { $_.count -gt 0 } |
    Sort-Object milliseconds
)
$histogramFrameCount = ($histogramBuckets | Measure-Object -Property count -Sum).Sum
$totalFrames = Get-LayerIntMetric 'totalFrames = (\d+)'
$surfaceTraceValid = $null -ne $totalFrames -and
  $totalFrames -ge $MinimumFrameCount -and
  $histogramFrameCount -gt 0

function Get-HistogramPercentile([double]$Percentile) {
  if (-not $surfaceTraceValid) { return $null }
  $target = [math]::Ceiling($histogramFrameCount * $Percentile)
  $cumulative = 0
  foreach ($bucket in $histogramBuckets) {
    $cumulative += $bucket.count
    if ($cumulative -ge $target) { return $bucket.milliseconds }
  }
  return $histogramBuckets[-1].milliseconds
}

$p50Ms = Get-HistogramPercentile 0.50
$p90Ms = Get-HistogramPercentile 0.90
$p95Ms = Get-HistogramPercentile 0.95
$p99Ms = Get-HistogramPercentile 0.99
$jankyFrames = if ($surfaceTraceValid) {
  ($histogramBuckets | Where-Object { $_.milliseconds -ge 34 } | Measure-Object -Property count -Sum).Sum
} else { $null }
$jankyPercent = if ($surfaceTraceValid) {
  [math]::Round(($jankyFrames / $histogramFrameCount) * 100, 2)
} else { $null }
$frameBudgetPassed = if ($null -eq $p95Ms) { $null } else { $p95Ms -le $MaxP95Ms }

$result = [ordered]@{
  timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
  variant = $Variant
  device = $serial
  minimum_api = $MinimumApi
  warmup_rounds = $WarmupRounds
  skip_install = [bool]$SkipInstall
  require_host_gpu = [bool]$RequireHostGpu
  gpu_renderer = $gpuRenderer
  package = $packageName
  activity = $activityName
  native_surface_only = $true
  tile_prefetch_disabled = [bool]$DisableTilePrefetch
  building_extrusion_disabled = [bool]$DisableBuildingExtrusion
  landcover_disabled = [bool]$DisableLandcover
  fill_antialias_disabled = [bool]$DisableFillAntialias
  roads_disabled = [bool]$DisableRoads
  water_disabled = [bool]$DisableWater
  water_outline_disabled = [bool]$DisableWaterOutline
  waterway_disabled = [bool]$DisableWaterway
  pier_disabled = [bool]$DisablePier
  when_dirty_refresh = [bool]$WhenDirtyRefresh
  style_uri = 'asset://fishergo_game_style.json'
  surfaceflinger_timestats_valid = [bool]$surfaceTraceValid
  surfaceflinger_layer = "SurfaceView[$packageName/$packageName.NativeMapProofActivity](BLAST)"
  total_frames = $totalFrames
  histogram_frame_count = $histogramFrameCount
  janky_frames = $jankyFrames
  janky_percent = $jankyPercent
  p50_ms = $p50Ms
  p90_ms = $p90Ms
  p95_ms = $p95Ms
  max_p95_ms = $MaxP95Ms
  minimum_frame_count = $MinimumFrameCount
  enforce_frame_budget = [bool]$EnforceFrameBudget
  frame_budget_passed = $frameBudgetPassed
  p99_ms = $p99Ms
  dropped_frames = Get-LayerIntMetric 'droppedFrames = (\d+)'
  average_fps = Get-LayerDoubleMetric 'averageFPS = ([\d.]+)'
  average_frame_duration_ms = Get-LayerDoubleMetric 'averageFrameDuration = ([\d.]+) ms'
  anr_detected = [bool]$anrDetected
}

$json = [pscustomobject]$result | ConvertTo-Json -Depth 5
if ($OutputPath) {
  $parent = Split-Path -Parent $OutputPath
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Set-Content -Path $OutputPath -Value $json -Encoding utf8
}

Write-Output $json
if ($anrDetected) {
  throw "Native MapLibre benchmark detected an application-not-responding state on $serial."
}
if (-not $surfaceTraceValid) {
  throw "Native MapLibre benchmark did not produce a valid SurfaceFlinger timestats trace with the minimum frame count on $serial."
}
if ($EnforceFrameBudget -and $null -eq $p95Ms) {
  throw "Frame budget gate requires a p95 metric on ${serial}."
}
if ($EnforceFrameBudget -and $frameBudgetPassed -eq $false) {
  throw "Frame budget exceeded on ${serial}: p95 ${p95Ms}ms > max ${MaxP95Ms}ms."
}
