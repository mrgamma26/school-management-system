#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and run the Flutter School Management App in release mode for web (Edge browser).

.DESCRIPTION
    This script:
    1. Loads dev.json environment configuration
    2. Gets Flutter dependencies
    3. Builds Flutter web in release mode
    4. Opens the built app in Microsoft Edge browser

.EXAMPLE
    PS> .\run-release.ps1
#>

param(
    [switch]$NoOpen,  # Skip opening browser
    [switch]$NoBuild  # Skip build, only open if built
)

# Colors for output
$Success = @{ ForegroundColor = 'Green' }
$Info = @{ ForegroundColor = 'Cyan' }
$Error = @{ ForegroundColor = 'Red' }
$Warning = @{ ForegroundColor = 'Yellow' }

Write-Host "🚀 Flutter School Management App - Release Build" @Info
Write-Host "=================================================" @Info
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
if (-not $NoBuild) {
    Write-Host "📦 Step 2: Getting Flutter dependencies..." @Info
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to get dependencies" @Error
        exit 1
    }
    Write-Host "✅ Dependencies retrieved" @Success
    Write-Host ""

    # Step 3: Build web release
    Write-Host "🔨 Step 3: Building Flutter web (release mode)..." @Info
    Write-Host "   This may take a few minutes..." @Warning
    flutter build web --release --web-renderer skwasm
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed" @Error
        exit 1
    }
    Write-Host "✅ Build completed successfully" @Success
    Write-Host ""
}

# Step 4: Open in Edge
if (-not $NoOpen) {
    Write-Host "🌐 Step 4: Opening in Microsoft Edge..." @Info
    $builtAppPath = ".\build\web\index.html"

    if (-not (Test-Path $builtAppPath)) {
        Write-Host "❌ Built app not found at $builtAppPath" @Error
        Write-Host "   Run build first with: flutter build web --release" @Warning
        exit 1
    }

    $fullPath = (Resolve-Path $builtAppPath).Path
    Start-Process "msedge.exe" "file:///$fullPath" -ErrorAction Continue

    Write-Host "✅ App opened in Edge" @Success
}

Write-Host ""
Write-Host "🎉 Done! App is running in release mode." @Success
Write-Host ""
Write-Host "📌 Tips:" @Info
Write-Host "   - Open DevTools: F12" @Info
Write-Host "   - To skip build next time: .\run-release.ps1 -NoBuild" @Info
Write-Host "   - To skip browser open: .\run-release.ps1 -NoOpen" @Info
