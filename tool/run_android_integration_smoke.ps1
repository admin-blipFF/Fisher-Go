param(
  [ValidateSet(
    'startup_auth_flow_test.dart',
    'app_resume_flow_test.dart',
    'panorama_map_flow_test.dart',
    'map_rotation_flow_test.dart',
    'map_spot_selection_flow_test.dart',
    'fishing_minigame_flow_test.dart',
    'daily_task_reward_flow_test.dart',
    'offline_reconnect_flow_test.dart',
    'offline_network_toggle_flow_test.dart',
    'location_permission_denied_flow_test.dart',
    'location_service_disabled_flow_test.dart',
    'limited_photo_permission_flow_test.dart'
  )]
  [string]$TestFile = 'startup_auth_flow_test.dart',
  [string]$DeviceSerial,
  [int]$TimeoutSeconds = 180,
  [switch]$ClearAppData,
  [switch]$ToggleNetwork,
  [double]$GeoLongitude = 114.1874,
  [double]$GeoLatitude = 22.3819,
  [ValidateSet('grant', 'deny-location', 'location-disabled', 'limited-photo', 'none')]
  [string]$PermissionProfile = 'grant'
)

$ErrorActionPreference = 'Stop'

# The map spot flow is tied to the verified Tsing Yi registry point. The
# runner's Sha Tin default is intentionally reserved for map/road smoke.
if ($TestFile -eq 'map_spot_selection_flow_test.dart' -and
    $GeoLongitude -eq 114.1874 -and
    $GeoLatitude -eq 22.3819) {
  throw 'map_spot_selection_flow_test.dart requires a verified-spot GPS override; use -GeoLongitude 114.109537072 -GeoLatitude 22.354208013.'
}

if ($ToggleNetwork -and $TestFile -ne 'offline_network_toggle_flow_test.dart') {
  throw '-ToggleNetwork is only valid with offline_network_toggle_flow_test.dart.'
}

$preflightScript = Join-Path $PSScriptRoot 'android_smoke_preflight.ps1'
if ($DeviceSerial) {
  $preflight = & $preflightScript -MinimumApi 35 -DeviceSerial $DeviceSerial
} else {
  $preflight = & $preflightScript -MinimumApi 35
}
$preflight | Write-Output
$deviceLine = $preflight | Where-Object { $_ -like 'ANDROID_SMOKE_DEVICE=*' } | Select-Object -First 1
if (-not $deviceLine) {
  throw 'Android smoke preflight did not return a device.'
}

$selectedDevice = $deviceLine -replace '^ANDROID_SMOKE_DEVICE=', ''

$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source

function Resolve-AdbPath {
  $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
  if ($adbCommand) {
    return $adbCommand.Source
  }

  $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (Test-Path $sdkAdb) {
    return $sdkAdb
  }

  return $null
}

function Invoke-Preflight {
  if ($PermissionProfile -eq 'grant') {
    if ($DeviceSerial) {
      return @(& $preflightScript -MinimumApi 35 -GrantRuntimePermissions -DeviceSerial $DeviceSerial)
    }

    return @(& $preflightScript -MinimumApi 35 -GrantRuntimePermissions)
  }

  if ($DeviceSerial) {
    return @(& $preflightScript -MinimumApi 35 -DeviceSerial $DeviceSerial)
  }

  return @(& $preflightScript -MinimumApi 35)
}

$adbPath = Resolve-AdbPath
if (-not $adbPath) {
  throw 'adb was not found; Android smoke requires platform-tools.'
}

if ($selectedDevice -like 'emulator-*') {
  $geoLongitudeText = $GeoLongitude.ToString(
    'R',
    [System.Globalization.CultureInfo]::InvariantCulture
  )
  $geoLatitudeText = $GeoLatitude.ToString(
    'R',
    [System.Globalization.CultureInfo]::InvariantCulture
  )
  & $adbPath -s $selectedDevice shell settings put secure location_mode 3 |
    Out-Null
  & $adbPath -s $selectedDevice emu geo fix $geoLongitudeText $geoLatitudeText |
    Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not set emulator GPS to $geoLatitudeText,$geoLongitudeText."
  }
  Write-Output "ANDROID_SMOKE_GEO=${geoLatitudeText},${geoLongitudeText}"
}

# Install once before granting permissions. pm grant silently fails for an
# absent package, which previously made clean-install permission evidence
# report DEFERRED even though the app itself had not run yet.
Push-Location $repoRoot
try {
  & $flutterCommand build apk --debug --no-pub `
    --dart-define=FISHERGO_MAPLIBRE=true
  if ($LASTEXITCODE -ne 0) {
    throw 'Flutter debug APK build failed before the Android smoke test.'
  }
} finally {
  Pop-Location
}

$apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apkPath)) {
  throw "Android smoke APK was not produced: $apkPath"
}

& $adbPath -s $selectedDevice install -r $apkPath | Write-Output
if ($LASTEXITCODE -ne 0) {
  throw "Could not install the Android smoke APK on $selectedDevice."
}

if ($ClearAppData) {
  if (-not $adbPath) {
    throw 'Cannot clear app data because adb was not found.'
  }

  $previousErrorAction = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & $adbPath -s $selectedDevice shell am force-stop com.fishergo.app 2>&1 | Out-Null
    & $adbPath -s $selectedDevice shell pm clear com.fishergo.app 2>&1 | Out-Null
    $clearExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  if ($clearExitCode -eq 0) {
    Write-Output 'ANDROID_SMOKE_APP_DATA=CLEARED'
  } else {
    Write-Warning 'FisherGO was not installed before the smoke run; app-data clear was skipped.'
    Write-Output 'ANDROID_SMOKE_APP_DATA=NOT_INSTALLED'
  }
}

$permissionPreflight = Invoke-Preflight
$permissionPreflight | Write-Output
if ($PermissionProfile -eq 'deny-location') {
  foreach ($permission in @(
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION'
    )) {
    & $adbPath -s $selectedDevice shell pm revoke com.fishergo.app $permission 2>$null | Out-Null
    & $adbPath -s $selectedDevice shell pm set-permission-flags `
      com.fishergo.app $permission user-set user-fixed 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not mark location permission denied on $selectedDevice."
    }
  }
}
if ($PermissionProfile -eq 'location-disabled') {
  & $adbPath -s $selectedDevice shell cmd location set-location-enabled false 2>$null | Out-Null
  $locationExitCode = $LASTEXITCODE
  if ($locationExitCode -ne 0) {
    throw "Could not disable location service on $selectedDevice."
  }
}
if ($PermissionProfile -eq 'limited-photo') {
  & $adbPath -s $selectedDevice shell pm revoke com.fishergo.app `
    android.permission.READ_MEDIA_IMAGES 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not revoke full photo access on $selectedDevice."
  }
  & $adbPath -s $selectedDevice shell pm grant com.fishergo.app `
    android.permission.READ_MEDIA_VISUAL_USER_SELECTED 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not grant selected-photo access on $selectedDevice."
  }
  & $adbPath -s $selectedDevice shell pm set-permission-flags `
    com.fishergo.app android.permission.READ_MEDIA_VISUAL_USER_SELECTED `
    user-set 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not mark selected-photo access on $selectedDevice."
  }
}
Write-Output "ANDROID_SMOKE_PERMISSION_PROFILE=$PermissionProfile"

$networkJob = $null
if ($ToggleNetwork) {
  & $adbPath -s $selectedDevice shell cmd connectivity airplane-mode enable |
    Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not disable emulator network before the smoke test on $selectedDevice."
  }
  & $adbPath -s $selectedDevice shell svc wifi disable | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not disable emulator Wi-Fi before the smoke test on $selectedDevice."
  }
  & $adbPath -s $selectedDevice shell svc data disable | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not disable emulator mobile data before the smoke test on $selectedDevice."
  }
  Write-Output "ANDROID_SMOKE_NETWORK=START_OFF:$selectedDevice"
  Start-Sleep -Seconds 2
}

$job = Start-Job -ScriptBlock {
  param(
    [string]$FlutterCommand,
    [string]$WorkingDirectory,
    [string]$SelectedDevice,
    [string]$SmokeTestFile
  )

  Set-Location $WorkingDirectory
  & $FlutterCommand test --no-pub `
    --dart-define=FISHERGO_MAPLIBRE=true `
    "integration_test/$SmokeTestFile" `
    -d $SelectedDevice
  $exitCode = $LASTEXITCODE
  Write-Output "ANDROID_SMOKE_FLUTTER_EXIT=$exitCode"
} -ArgumentList $flutterCommand, $repoRoot, $selectedDevice, $TestFile

if ($ToggleNetwork) {
  $networkJob = Start-Job -ScriptBlock {
    param(
      [string]$AdbPath,
      [string]$SelectedDevice
    )

    $appReady = $false
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
      $processId = (& $AdbPath -s $SelectedDevice shell pidof com.fishergo.app).Trim()
      if ($processId) {
        $appReady = $true
        break
      }
      Start-Sleep -Seconds 1
    }
    if (-not $appReady) {
      Write-Output 'ANDROID_SMOKE_NETWORK_APP_READY=FAIL'
      exit 1
    }
    Write-Output 'ANDROID_SMOKE_NETWORK_APP_READY=PASS'
    # Give the integration test time to seed Hive and subscribe to the
    # production Connectivity stream before restoring the emulator network.
    Start-Sleep -Seconds 15
    & $AdbPath -s $SelectedDevice shell cmd connectivity airplane-mode disable |
      Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Output 'ANDROID_SMOKE_NETWORK_ON=FAIL'
      exit 1
    }
    & $AdbPath -s $SelectedDevice shell svc wifi enable | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Output 'ANDROID_SMOKE_NETWORK_ON=FAIL'
      exit 1
    }
    & $AdbPath -s $SelectedDevice shell svc data enable | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Output 'ANDROID_SMOKE_NETWORK_ON=FAIL'
      exit 1
    }
    Write-Output 'ANDROID_SMOKE_NETWORK_ON=PASS'
  } -ArgumentList $adbPath, $selectedDevice
}

try {
  $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
  if ($null -eq $completed) {
    Write-Output "ANDROID_SMOKE_TIMEOUT=$TimeoutSeconds"
    $partialOutput = @(Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue)
    Write-Output 'ANDROID_SMOKE_FLUTTER_OUTPUT_BEGIN'
    if ($partialOutput.Count -gt 0) {
      $partialOutput | Select-Object -Last 80 | Write-Output
    } else {
      Write-Output 'No Flutter output was returned before timeout.'
    }
    Write-Output 'ANDROID_SMOKE_FLUTTER_OUTPUT_END'
    $adbPath = Resolve-AdbPath
    if ($adbPath) {
      Write-Output 'ANDROID_SMOKE_DIAGNOSTICS_BEGIN'
      & $adbPath -s $selectedDevice get-state
      & $adbPath -s $selectedDevice shell getprop ro.build.version.sdk
      & $adbPath -s $selectedDevice shell pidof com.fishergo.app
      & $adbPath -s $selectedDevice logcat -d -t 200
      Write-Output 'ANDROID_SMOKE_DIAGNOSTICS_END'
    } else {
      Write-Warning 'adb was unavailable; timeout diagnostics were skipped.'
    }

    Stop-Job -Job $job -ErrorAction SilentlyContinue
    exit 124
  }

  $jobOutput = @(Receive-Job -Job $job -ErrorAction Continue)
  $jobOutput | Where-Object {
    $_ -notmatch '^ANDROID_SMOKE_FLUTTER_EXIT='
  } | Write-Output
  $exitLine = $jobOutput |
    Where-Object { $_ -match '^ANDROID_SMOKE_FLUTTER_EXIT=' } |
    Select-Object -Last 1
  if (-not $exitLine) {
    throw 'Android smoke runner did not return a Flutter exit code.'
  }

  $exitCode = [int]($exitLine -replace '^ANDROID_SMOKE_FLUTTER_EXIT=', '')
  exit $exitCode
} finally {
  if ($networkJob) {
    $networkOutput = @(Receive-Job -Job $networkJob -Keep -ErrorAction SilentlyContinue)
    $networkOutput | Write-Output
    Stop-Job -Job $networkJob -ErrorAction SilentlyContinue
    Remove-Job -Job $networkJob -Force -ErrorAction SilentlyContinue
  }
  if ($ToggleNetwork) {
    & $adbPath -s $selectedDevice shell cmd connectivity airplane-mode disable |
      Out-Null
    & $adbPath -s $selectedDevice shell svc wifi enable | Out-Null
    & $adbPath -s $selectedDevice shell svc data enable | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Output "ANDROID_SMOKE_NETWORK_RESTORED=$selectedDevice"
    } else {
      Write-Warning "Could not restore emulator network on $selectedDevice."
    }
  }
  if ($PermissionProfile -eq 'location-disabled') {
    & $adbPath -s $selectedDevice shell cmd location set-location-enabled true 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Output "ANDROID_SMOKE_LOCATION_RESTORED=$selectedDevice"
    } else {
      Write-Warning "Could not restore location service on $selectedDevice."
    }
  }
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}
