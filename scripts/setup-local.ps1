#!/usr/bin/env pwsh

param(
    [string]$AdminEmail = "admin@local.school",
    [switch]$SkipDatabaseReset
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

foreach ($commandName in @('flutter', 'supabase', 'docker')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$commandName' was not found. See docs/COLLABORATOR_SETUP.md."
    }
}

Write-Host "Starting the isolated local Supabase stack..." -ForegroundColor Cyan
& supabase start
if ($LASTEXITCODE -ne 0) {
    throw "Supabase failed to start. Confirm Docker is running and retry."
}

if (-not $SkipDatabaseReset) {
    Write-Host "Rebuilding the LOCAL database from committed migrations..." -ForegroundColor Cyan
    & supabase db reset --local
    if ($LASTEXITCODE -ne 0) {
        throw "The local database reset failed. Review the migration error above."
    }
}

$statusOutput = & supabase status -o env
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the local Supabase connection values."
}

$values = @{}
foreach ($line in $statusOutput) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') {
        $values[$Matches[1]] = $Matches[2].Trim().Trim('"')
    }
}

$apiUrl = $values['API_URL']
$publishableKey = $values['PUBLISHABLE_KEY']
if (-not $publishableKey) {
    $publishableKey = $values['ANON_KEY']
}
if (-not $apiUrl -or -not $publishableKey) {
    throw "Supabase status did not provide API_URL and a publishable or anon key."
}

$envDirectory = Join-Path $projectRoot 'env'
New-Item -ItemType Directory -Force -Path $envDirectory | Out-Null
$clientConfig = [ordered]@{
    SUPABASE_URL = $apiUrl
    SUPABASE_PUBLISHABLE_KEY = $publishableKey
} | ConvertTo-Json
$clientConfig | Set-Content -Path (Join-Path $envDirectory 'dev.json') -Encoding utf8
Write-Host "Created ignored env/dev.json with LOCAL client values." -ForegroundColor Green

& (Join-Path $PSScriptRoot 'bootstrap-local-super-user.ps1') -Email $AdminEmail

Write-Host "Getting Flutter dependencies..." -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "Flutter dependency installation failed."
}

Write-Host "Local setup is complete. Run .\run-dev.ps1" -ForegroundColor Green
