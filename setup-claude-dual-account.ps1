[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string] $PrimaryEmail,

    [Parameter(Mandatory)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string] $SecondaryEmail,

    [ValidatePattern('^(latest|\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$')]
    [string] $ClaudeCodeVersion = '2.1.197',

    [ValidatePattern('^(latest|\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$')]
    [string] $CcxVersion = '1.47.0',

    [switch] $InstallEditorIntegration
)

$ErrorActionPreference = 'Stop'

function Assert-LastExitCode {
    param([Parameter(Mandatory)] [string] $Step)
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

function Copy-IfPresent {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Destination
    )
    if (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required. Install it from https://aka.ms/powershell-release?tag=stable'
}

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$npmCommand = Get-Command npm -ErrorAction SilentlyContinue
if (-not $nodeCommand -or -not $npmCommand) {
    throw 'Node.js 22 LTS is required. Install it from https://nodejs.org/ and run this script again.'
}

$nodeVersionText = (& node --version).TrimStart('v')
$nodeVersion = [version]($nodeVersionText -replace '-.*$', '')
if ($nodeVersion.Major -lt 20) {
    throw "Node.js 20 or newer is required; found $nodeVersionText. Node.js 22 LTS is recommended."
}

$runningClaude = Get-Process -Name 'claude' -ErrorAction SilentlyContinue
if ($runningClaude) {
    throw 'Close all running Claude Code sessions before setup, then run this script again.'
}

$ccxHome = Join-Path $env:USERPROFILE '.claude-auto-switch'
$registryFile = Join-Path $ccxHome 'accounts.json'
if (Test-Path -LiteralPath $registryFile) {
    throw "An existing ccx account registry was found at $registryFile. This bootstrap intentionally does not overwrite it. Run 'ccx doctor' instead."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "ClaudeSetupBackup-$stamp"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$profileAllHosts = $PROFILE.CurrentUserAllHosts
$profileCurrentHost = $PROFILE.CurrentUserCurrentHost
Copy-IfPresent -Source $profileAllHosts -Destination (Join-Path $backupRoot 'PowerShell-profile-AllHosts.ps1')
Copy-IfPresent -Source $profileCurrentHost -Destination (Join-Path $backupRoot 'PowerShell-profile-CurrentHost.ps1')
Copy-IfPresent -Source (Join-Path $env:USERPROFILE '.claude\.credentials.json') -Destination (Join-Path $backupRoot 'claude.credentials.json')
Copy-IfPresent -Source (Join-Path $env:USERPROFILE '.claude.json') -Destination (Join-Path $backupRoot 'claude.json')
Copy-IfPresent -Source (Join-Path $env:USERPROFILE '.claude\settings.json') -Destination (Join-Path $backupRoot 'claude.settings.json')

Write-Host "Backup created: $backupRoot" -ForegroundColor Cyan
Write-Host "Installing Claude Code $ClaudeCodeVersion and ccx $CcxVersion..." -ForegroundColor Cyan

$packages = @(
    "@anthropic-ai/claude-code@$ClaudeCodeVersion",
    "claude-auto-switch@$CcxVersion"
)
& npm install --global @packages
Assert-LastExitCode -Step 'Global npm installation'

& claude --version
Assert-LastExitCode -Step 'Claude Code verification'
& ccx --version
Assert-LastExitCode -Step 'ccx verification'

Write-Host ''
Write-Host "Primary login: $PrimaryEmail" -ForegroundColor Green
Write-Host 'Complete the browser authorization using the PRIMARY Claude subscription.' -ForegroundColor Yellow
& ccx add primary --email $PrimaryEmail
Assert-LastExitCode -Step 'Primary account registration'

Write-Host ''
Write-Host 'Before adding the second account:' -ForegroundColor Yellow
Write-Host '  1. Sign out of claude.ai in the browser, or switch to a different browser profile.'
Write-Host "  2. Make sure the browser will authorize $SecondaryEmail."
[void](Read-Host 'Press Enter when the browser is ready for the SECONDARY account')

Write-Host "Secondary login: $SecondaryEmail" -ForegroundColor Green
& ccx add secondary --email $SecondaryEmail
Assert-LastExitCode -Step 'Secondary account registration'

Write-Host ''
Write-Host 'Verifying that both profiles are signed in and belong to different accounts...' -ForegroundColor Cyan
& ccx doctor
Assert-LastExitCode -Step 'ccx doctor before shell integration'

$onArguments = @('on')
if (-not $InstallEditorIntegration) {
    $onArguments += '--no-editor'
}
& ccx @onArguments
Assert-LastExitCode -Step 'ccx shell integration'

Write-Host ''
& ccx list
Assert-LastExitCode -Step 'ccx account listing'
& ccx usage
Assert-LastExitCode -Step 'ccx usage check'

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host 'Open a new PowerShell window, enter your project directory, and run: claude'
Write-Host 'Manual immediate switch while preserving the conversation:'
Write-Host '  ccx use primary --now'
Write-Host '  ccx use secondary --now'
Write-Host "Rollback backup: $backupRoot"
