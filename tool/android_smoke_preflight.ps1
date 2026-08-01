param(
  [string]$DeviceSerial,
  [int]$MinimumApi = 35,
  [string]$KnownInvalidSerial = '0123456789ABCDEF',
  [switch]$GrantRuntimePermissions
)

$ErrorActionPreference = 'Stop'
$adb = Get-Command adb -ErrorAction SilentlyContinue
if ($null -eq $adb) {
  $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (-not (Test-Path $sdkAdb)) {
    throw 'adb was not found. Install Android platform-tools or add adb to PATH.'
  }
  $adbPath = $sdkAdb
} else {
  $adbPath = $adb.Source
}

$rows = & $adbPath devices
$serials = $rows | Select-Object -Skip 1 | Where-Object {
  $_ -match '^\S+\s+device\s*$'
} | ForEach-Object { ($_ -split '\s+')[0] }

if ($serials.Count -eq 0) {
  throw 'No online Android devices found.'
}

$candidates = foreach ($serial in $serials) {
  if ($serial -eq $KnownInvalidSerial) {
    Write-Warning "Skipping known invalid API 23 photo-frame device: $serial"
    continue
  }

  $api = (& $adbPath -s $serial shell getprop ro.build.version.sdk).Trim()
  $model = (& $adbPath -s $serial shell getprop ro.product.model).Trim()
  if ([int]$api -lt $MinimumApi) {
    Write-Warning "Skipping $serial ($model): API $api is below required API $MinimumApi"
    continue
  }

  [pscustomobject]@{
    Serial = $serial
    Model = $model
    Api = [int]$api
  }
}

if ($DeviceSerial) {
  $selected = $candidates | Where-Object Serial -eq $DeviceSerial
  if ($null -eq $selected) {
    throw "Requested Android device '$DeviceSerial' did not pass the API preflight."
  }
} else {
  $selected = $candidates | Select-Object -First 1
}

if ($null -eq $selected) {
  throw "No Android emulator passed the API $MinimumApi preflight."
}

if ($GrantRuntimePermissions) {
  # Smoke tests must start on the game surface, not behind a system dialog.
  $runtimePermissions = @(
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VISUAL_USER_SELECTED'
  )
  $permissionGrantState = 'GRANTED'
  foreach ($permission in $runtimePermissions) {
    try {
      & $adbPath -s $selected.Serial shell pm grant com.fishergo.app $permission 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) {
        $permissionGrantState = 'DEFERRED'
        Write-Warning "Could not grant smoke permission '$permission'; continuing."
      }
    } catch {
      $permissionGrantState = 'DEFERRED'
      Write-Warning "Could not grant smoke permission '$permission'; continuing."
    }
  }
  Write-Output "ANDROID_SMOKE_PERMISSIONS=$permissionGrantState"
}

Write-Output "ANDROID_SMOKE_DEVICE=$($selected.Serial)"
Write-Output "ANDROID_SMOKE_MODEL=$($selected.Model)"
Write-Output "ANDROID_SMOKE_API=$($selected.Api)"
