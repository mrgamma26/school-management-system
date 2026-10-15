#!/usr/bin/env pwsh

param(
    [string]$Email = "admin@local.school"
)

$ErrorActionPreference = "Stop"

function Get-LocalSupabaseEnvironment {
    $statusOutput = & supabase status -o env
    if ($LASTEXITCODE -ne 0) {
        throw "Supabase is not running. Run 'supabase start' first."
    }

    $values = @{}
    foreach ($line in $statusOutput) {
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            $values[$Matches[1]] = $Matches[2].Trim().Trim('"')
        }
    }
    return $values
}

function New-TemporaryPassword {
    $bytes = [byte[]]::new(18)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return ([Convert]::ToBase64String($bytes).Replace('/', 'A').Replace('+', 'b') + '!9a')
}

$environment = Get-LocalSupabaseEnvironment
$apiUrl = $environment['API_URL']
$serviceRoleKey = $environment['SERVICE_ROLE_KEY']
if (-not $serviceRoleKey) {
    $serviceRoleKey = $environment['SECRET_KEY']
}

if (-not $apiUrl -or -not $serviceRoleKey) {
    throw "Could not read API_URL and SERVICE_ROLE_KEY from the local Supabase stack."
}

$headers = @{
    apikey        = $serviceRoleKey
    Authorization = "Bearer $serviceRoleKey"
    'Content-Type' = 'application/json'
}

$usersResponse = Invoke-RestMethod -Method Get -Uri "$apiUrl/auth/v1/admin/users?page=1&per_page=1000" -Headers $headers
$existingUser = $usersResponse.users | Where-Object { $_.email -eq $Email } | Select-Object -First 1
$temporaryPassword = $null

if ($existingUser) {
    $userId = $existingUser.id
    Write-Host "Local Auth user already exists: $Email" -ForegroundColor Yellow
}
else {
    $temporaryPassword = New-TemporaryPassword
    $createBody = @{
        email = $Email
        password = $temporaryPassword
        email_confirm = $true
        user_metadata = @{
            first_name = 'Local'
            last_name = 'Administrator'
        }
    } | ConvertTo-Json -Depth 4

    $createdUser = Invoke-RestMethod -Method Post -Uri "$apiUrl/auth/v1/admin/users" -Headers $headers -Body $createBody
    $userId = $createdUser.id
}

$role = Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/role?select=roleid&rolename=eq.SUPER_USER" -Headers $headers
if (-not $role -or -not $role[0].roleid) {
    throw "The SUPER_USER role was not found after migrations completed."
}

$username = $Email.Split('@')[0]
$systemUserBody = @{
    userid = $userId
    username = $username
    roleid = $role[0].roleid
    mustchangepassword = $true
    isactive = $true
} | ConvertTo-Json

$upsertHeaders = $headers.Clone()
$upsertHeaders['Prefer'] = 'resolution=merge-duplicates,return=representation'
Invoke-RestMethod -Method Post -Uri "$apiUrl/rest/v1/systemuser?on_conflict=userid" -Headers $upsertHeaders -Body $systemUserBody | Out-Null

Write-Host "Local Super User is ready: $Email" -ForegroundColor Green
if ($temporaryPassword) {
    Write-Host "Temporary password: $temporaryPassword" -ForegroundColor Cyan
    Write-Host "Copy it now. It is not saved to a file and must be changed after first sign-in." -ForegroundColor Yellow
}
else {
    Write-Host "The existing password was not changed. Reset it in local Supabase Studio if necessary." -ForegroundColor Yellow
}
