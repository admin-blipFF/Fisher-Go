param(
  [string]$InputPath = 'assets\fish\mobile',
  [string]$OutputPath = 'assets\fish\mobile_webp',
  [int]$Quality = 82
)

$ErrorActionPreference = 'Stop'

$ffmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
  throw 'ffmpeg.exe was not found. Install FFmpeg before rebuilding mobile fish assets.'
}

$source = Resolve-Path $InputPath -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$files = Get-ChildItem $source -Filter '*.png' -File
if ($files.Count -eq 0) {
  throw "No PNG fish assets found under '$InputPath'."
}

$failed = @()
foreach ($file in $files) {
  $destination = Join-Path $OutputPath ($file.BaseName + '.webp')
  & $ffmpeg.Source -hide_banner -loglevel error -y -i $file.FullName `
    -c:v libwebp -lossless 0 -q:v $Quality -compression_level 6 -preset picture `
    $destination
  if ($LASTEXITCODE -ne 0) {
    $failed += $file.Name
  }
}

if ($failed.Count -gt 0) {
  throw "Failed to convert: $($failed -join ', ')"
}

$outputs = Get-ChildItem $OutputPath -Filter '*.webp' -File
Write-Output "Converted $($files.Count) PNG fish assets to $($outputs.Count) WebP assets."
