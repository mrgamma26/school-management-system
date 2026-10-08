#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run the Flutter School Management App in debug mode for web (Edge browser).

.DESCRIPTION
    This script:
    1. Loads dev.json environment configuration
    2. Gets Flutter dependencies
    3. Runs Flutter web in debug mode with hot reload
    4. Opens the app in Microsoft Edge browser

.EXAMPLE
    PS> .\run-dev.ps1
#>

# Colors for output
$Success = @{ ForegroundColor = 'Green' }
$Info = @{ ForegroundColor = 'Cyan' }
$Error = @{ ForegroundColor = 'Red' }
$Warning = @{ ForegroundColor = 'Yellow' }

Write-Host "🚀 Flutter School Management App - Debug Mode" @Info
Write-Host "=============================================" @Info
Write-Host ""

# Step 1: Load dev.json
Write-Host "📋 Step 1: Loading dev.json configuration..." @Info
$devJsonPath = "env/dev.json"

if (-not (Test-Path $devJsonPath)) {
    Write-Host "❌ dev.json not found at $devJsonPath" @Error
    exit 1
}

try {
    $config = Get-Content $devJsonPath | ConvertFrom-Json
    Write-Host "✅ Configuration loaded successfully" @Success
    Write-Host "   Supabase URL: $($config.SUPABASE_URL)" @Info
    Write-Host ""
}
catch {
    Write-Host "❌ Failed to parse dev.json: $_" @Error
    exit 1
}

# Step 2: Get dependencies
Write-Host "📦 Step 2: Getting Flutter dependencies..." @Info
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies" @Error
    exit 1
}
Write-Host "✅ Dependencies retrieved" @Success
Write-Host ""

# Step 3: Run web debug
Write-Host "🔧 Step 3: Running Flutter web (debug mode)..." @Info
Write-Host "   Hot reload enabled - press 'r' to reload, 'q' to quit" @Warning
Write-Host ""

flutter run -d edge --web-port=8080 --dart-define-from-file=env/dev.json --no-web-resources-cdn
