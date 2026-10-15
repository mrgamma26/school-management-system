#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run the Flutter School Management App in release mode for web.

.DESCRIPTION
    Validates the ignored client configuration and launches the app through
    Flutter's web server. This avoids unreliable file:// loading and ensures
    the Supabase client values are compiled into the release build.

.EXAMPLE
    PS> .\run-release.ps1
    PS> .\run-release.ps1 -Browser web-server -Port 8081
#>

param(
    [ValidateSet('edge', 'chrome', 'web-server')]
    [string]$Browser = 'edge',
    [ValidateRange(1024, 65535)]
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'
$Success = @{ ForegroundColor = 'Green' }
$Info = @{ ForegroundColor = 'Cyan' }
$ErrorColour = @{ ForegroundColor = 'Red' }

$devJsonPath = Join-Path $PSScriptRoot 'env/dev.json'
if (-not (Test-Path $devJsonPath)) {
    Write-Host "env/dev.json was not found." @ErrorColour
    Write-Host "Run .\scripts\setup-local.ps1 or copy env/dev.example.json and add development client values." @Info
    exit 1
}

try {
    $config = Get-Content $devJsonPath -Raw | ConvertFrom-Json
    if (-not $config.SUPABASE_URL -or -not $config.SUPABASE_PUBLISHABLE_KEY) {
        throw 'Both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.'
    }
}
catch {
    Write-Host "env/dev.json is invalid: $_" @ErrorColour
    exit 1
}

Write-Host "Starting the release-mode web app on port $Port..." @Info
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Flutter dependency installation failed.' @ErrorColour
    exit 1
}

& flutter run `
    -d $Browser `
    --release `
    --web-port=$Port `
    --dart-define-from-file=$devJsonPath `
    --no-web-resources-cdn

if ($LASTEXITCODE -ne 0) {
    Write-Host 'The release-mode run failed.' @ErrorColour
    exit 1
}

Write-Host 'Release-mode run finished.' @Success
