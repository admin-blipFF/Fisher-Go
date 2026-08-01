[CmdletBinding()]
param(
    [switch]$PromoteProduction
)

$ErrorActionPreference = 'Stop'

if (-not $PromoteProduction) {
    throw 'Production deployment is disabled by default. Re-run with -PromoteProduction after owner review.'
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot

$dirtyFiles = @(git status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect Git worktree before production deployment.'
}
if ($dirtyFiles.Count -gt 0) {
    throw 'Production deployment requires a clean Git worktree.'
}

function Import-DotEnv {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing environment file: $Path"
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^(?:export\s+)?(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<value>.*)$') {
            $name = $Matches.name
            $value = $Matches.value.Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

function Require-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name is required for production deployment"
    }
    return $value
}

if (Test-Path -LiteralPath (Join-Path $projectRoot '.env') -PathType Leaf) {
    Import-DotEnv (Join-Path $projectRoot '.env')
} else {
    Write-Host 'No .env file; using the current environment.'
}

$vercelToken = Require-EnvironmentValue 'VERCEL_TOKEN'
$supabaseUrl = Require-EnvironmentValue 'SUPABASE_URL'
$supabaseAnonKey = Require-EnvironmentValue 'SUPABASE_ANON_KEY'

$hkNow = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, 'China Standard Time')
$buildTime = $hkNow.ToString('yyyy-MM-dd HH:mm') + ' HKT'
$buildId = $hkNow.ToString('yyyyMMddHHmmss')

$gitSha = $env:FISHERGO_GIT_SHA
if ([string]::IsNullOrWhiteSpace($gitSha)) {
    $gitSha = (& git rev-parse HEAD 2>$null | Select-Object -First 1)
    if ($null -ne $gitSha) {
        $gitSha = $gitSha.ToString().Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($gitSha)) {
    $gitSha = 'unknown'
}

$versionLine = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') |
    Where-Object { $_ -match '^version:\s*([^\s#]+)' } |
    Select-Object -First 1
$appVersion = if ($versionLine -match '^version:\s*([^\s#]+)') { $Matches[1] } else { 'unknown' }

$releaseId = $env:FISHERGO_RELEASE_ID
if ([string]::IsNullOrWhiteSpace($releaseId)) {
    if ($gitSha -eq 'unknown') {
        $releaseId = "$appVersion-$buildId"
    } else {
        $releaseId = "$appVersion-$($gitSha.Substring(0, [Math]::Min(12, $gitSha.Length)))"
    }
}

$releaseProvenancePath = Join-Path $projectRoot '.fishergo-deploy-release-id'
$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
[System.IO.File]::WriteAllText($releaseProvenancePath, $releaseId, $utf8NoBom)

try {
    Write-Host "Build time: $buildTime"
    Write-Host "Release ID: $releaseId"
    Write-Host 'Building web...'

$privacyUrl = if ([string]::IsNullOrWhiteSpace($env:FISHERGO_PRIVACY_URL)) { '' } else { $env:FISHERGO_PRIVACY_URL }
$supportEmail = if ([string]::IsNullOrWhiteSpace($env:FISHERGO_SUPPORT_EMAIL)) { '' } else { $env:FISHERGO_SUPPORT_EMAIL }
$analyticsEnabled = if ([string]::IsNullOrWhiteSpace($env:FISHERGO_ANALYTICS_ENABLED)) { 'false' } else { $env:FISHERGO_ANALYTICS_ENABLED }
$flutterArgs = @(
    'build',
    'web',
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
    "--dart-define=FISHERGO_PRIVACY_URL=$privacyUrl",
    "--dart-define=FISHERGO_SUPPORT_EMAIL=$supportEmail",
    "--dart-define=FISHERGO_ANALYTICS_ENABLED=$analyticsEnabled",
    '--dart-define=FISHERGO_MAPLIBRE=true',
    "--dart-define=FISHERGO_RELEASE_ID=$releaseId",
    "--dart-define=BUILD_TIME=$buildTime"
)
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) {
    throw "flutter build web failed with exit code $LASTEXITCODE"
}

$versionJson = [ordered]@{
    build_id   = $buildId
    build_time = $buildTime
} | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText(
    (Join-Path $projectRoot 'build/web/version.json'),
    $versionJson + [Environment]::NewLine,
    $utf8NoBom
)

$env:FISHERGO_BUILD_ID = $buildId
$env:FISHERGO_BUILD_TIME = $buildTime
$env:FISHERGO_GIT_SHA = $gitSha
$env:FISHERGO_RELEASE_ID = $releaseId
& dart run tool/write_release_manifest.dart build/web/release-manifest.json
if ($LASTEXITCODE -ne 0) {
    throw "Release manifest generation failed with exit code $LASTEXITCODE"
}

& dart run tool/check_client_artifacts_for_secrets.dart build/web
if ($LASTEXITCODE -ne 0) {
    throw "Client artifact secret scan failed with exit code $LASTEXITCODE"
}

$vercelProject = if ([string]::IsNullOrWhiteSpace($env:VERCEL_PROJECT)) { 'fishergo' } else { $env:VERCEL_PROJECT }
$publicUrl = if ([string]::IsNullOrWhiteSpace($env:FISHERGO_PUBLIC_URL)) { 'https://fisher-go.app' } else { $env:FISHERGO_PUBLIC_URL }
$publicAliasUrl = if ([string]::IsNullOrWhiteSpace($env:FISHERGO_PUBLIC_ALIAS_URL)) { 'https://www.fisher-go.app' } else { $env:FISHERGO_PUBLIC_ALIAS_URL }

$primaryUri = [Uri]$publicUrl
$aliasUri = [Uri]$publicAliasUrl
if ($primaryUri.Scheme -ne 'https' -or $primaryUri.Host -ne 'fisher-go.app' -or
    $aliasUri.Scheme -ne 'https' -or $aliasUri.Host -ne 'www.fisher-go.app') {
    throw 'Production deploy only permits https://fisher-go.app and https://www.fisher-go.app aliases.'
}

Write-Host 'Deploying to Vercel production...'
$vercelDeployArgs = @(
    'deploy',
    '.',
    '--prod',
    "--project=$vercelProject",
    "--token=$vercelToken",
    '--build-env',
    "SUPABASE_URL=$supabaseUrl",
    '--build-env',
    "SUPABASE_ANON_KEY=$supabaseAnonKey",
    '--build-env',
    "FISHERGO_PRIVACY_URL=$privacyUrl",
    '--build-env',
    "FISHERGO_SUPPORT_EMAIL=$supportEmail",
    '--build-env',
    "FISHERGO_ANALYTICS_ENABLED=$analyticsEnabled",
    '--build-env',
    "FISHERGO_DEPLOY_RELEASE_ID=$releaseId",
    '--build-env',
    "FISHERGO_RELEASE_ID=$releaseId",
    '--build-env',
    "FISHERGO_GIT_SHA=$gitSha",
    '--yes'
)
$deployOutput = (& npx --yes vercel @vercelDeployArgs 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "Vercel production deployment failed with exit code $LASTEXITCODE"
}
Write-Output $deployOutput

$deploymentMatches = [regex]::Matches($deployOutput, 'https://[^\s]+\.vercel\.app')
if ($deploymentMatches.Count -eq 0) {
    throw 'Could not determine the Vercel production deployment URL.'
}
$deploymentUrl = $deploymentMatches[$deploymentMatches.Count - 1].Value.TrimEnd('.', ')', ']', ',')

foreach ($domain in @($primaryUri.Host, $aliasUri.Host)) {
    Write-Host "Promoting deployment to $domain..."
    & npx --yes vercel alias set $deploymentUrl $domain "--token=$vercelToken"
    if ($LASTEXITCODE -ne 0) {
        throw "Vercel alias promotion failed for $domain with exit code $LASTEXITCODE"
    }
}

Write-Host 'Verifying public aliases and secret asset boundary...'
& dart run tool/verify_deployed_web.dart "--url=$publicUrl" "--alias=$publicAliasUrl" "--release-id=$releaseId"
if ($LASTEXITCODE -ne 0) {
    throw "Public deployment verification failed with exit code $LASTEXITCODE"
}

Write-Host 'Production deployment complete.'
} finally {
    Remove-Item -LiteralPath $releaseProvenancePath -Force -ErrorAction SilentlyContinue
}
