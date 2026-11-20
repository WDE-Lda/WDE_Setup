#Requires -Version 5.1
<#
.SYNOPSIS
Prepares a new WDE PC: Git, GitHub CLI, GitHub sign-in, GitWorkflow, the WDE_AI setup and the Git configuration.

.DESCRIPTION
This script is public on purpose and holds no secrets: the WDE repositories are private, so the only
thing a new PC needs first is a GitHub sign-in. The script installs Git and the GitHub CLI with winget,
asks you to sign in to GitHub in the browser (once), then downloads GitWorkflow from its private release,
installs it and runs 'Install-Workstation', which runs the WDE_AI bootstrap and configures Git.

Run it in PowerShell:
    irm https://raw.githubusercontent.com/WDE-Lda/WDE_Setup/main/setup.ps1 | iex
With options:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/WDE-Lda/WDE_Setup/main/setup.ps1))) -Extras

.PARAMETER Extras
Also installs ripgrep, jq, ShellCheck and shfmt.

.PARAMETER NoNode
Skips Node.js.

.PARAMETER SkipPlugins
Leaves Claude Code plugins untouched.
#>
[CmdletBinding()]
param(
    [switch]$Extras,
    [switch]$NoNode,
    [switch]$SkipPlugins
)

$ErrorActionPreference = 'Stop'

function Update-SessionPath {
    $parts = foreach ($scope in 'Machine', 'User') {
        $value = [Environment]::GetEnvironmentVariable('Path', $scope)
        if ($value) { $value -split ';' }
    }
    $env:Path = (@($parts + ($env:Path -split ';')) | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Install-WingetPackage {
    param([string]$Command, [string]$Id, [string]$Name)
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "OK: $Name already installed"
        return
    }
    Write-Host "==> Installing $Name"
    winget install --id $Id --exact --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget could not install $Name (exit code $LASTEXITCODE)."
    }
    Update-SessionPath
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available. Install "App Installer" from the Microsoft Store and run again.'
}
Install-WingetPackage -Command git -Id Git.Git -Name 'Git'
Install-WingetPackage -Command gh -Id GitHub.cli -Name 'GitHub CLI'

gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host '==> GitHub sign-in (the WDE repositories are private): follow the steps in the browser'
    gh auth login --hostname github.com --git-protocol https --web --scopes read:packages
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub sign-in failed.'
    }
}

# The WDE libraries (Hamr, Mimir, Asgard) are NuGet packages in the GitHub Packages of WDE-Lda, which asks for a
# sign-in even to read. NuGet gets the GitHub sign-in of this PC (with the read:packages scope) for the source
# "wde" that the nuget.config of each program names; dotnet stores it encrypted in the user's NuGet.Config.
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host '==> NuGet source "wde" (the WDE libraries, from GitHub Packages)'
    if (-not (gh api user --include | Select-String -Pattern '^X-Oauth-Scopes:.*read:packages' -Quiet)) {
        Write-Host '    The GitHub sign-in needs the permission to read packages: follow the steps in the browser'
        gh auth refresh --hostname github.com --scopes read:packages
    }
    $userConfig = Join-Path $env:AppData 'NuGet\NuGet.Config'
    dotnet nuget list source | Out-Null # creates the user's NuGet.Config on a PC where NuGet never ran
    $sources = dotnet nuget list source --configfile $userConfig
    $known = @($sources) -match '^\s*\d+\.\s+wde \['
    $target = if ($known) { @('update', 'source', 'wde') } else { @('add', 'source', 'https://nuget.pkg.github.com/WDE-Lda/index.json', '--name', 'wde') }
    dotnet nuget @target --username (gh api user --jq .login) --password (gh auth token) --configfile $userConfig
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'The NuGet source "wde" was not configured: programs that use Hamr, Mimir or Asgard will not restore. Run this setup again.'
    }
}
else {
    Write-Host 'SKIPPED: NuGet source "wde" (no .NET SDK on this PC). Run this setup again after installing it.'
}

$stage = Join-Path ([IO.Path]::GetTempPath()) ('WDE-launcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Write-Host '==> Downloading GitWorkflow'
    gh release download --repo WDE-Lda/GitWorkflow --pattern GitWorkflow.zip --pattern GitWorkflow.zip.sha256 --dir $stage --clobber
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to download GitWorkflow. Is the signed-in GitHub account a collaborator on WDE-Lda/GitWorkflow?'
    }
    $zip = Join-Path $stage 'GitWorkflow.zip'
    $checksumFile = "$zip.sha256"
    if (-not (Test-Path -LiteralPath $checksumFile)) {
        throw 'The latest GitWorkflow release has no GitWorkflow.zip.sha256, so the download cannot be verified. Publish a GitWorkflow release that includes it and run again.'
    }
    # Format: '<hash>  GitWorkflow.zip'
    $expected = (-split (Get-Content -LiteralPath $checksumFile -Raw)) | Select-Object -First 1
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        throw "GitWorkflow.zip failed the SHA-256 check (expected '$expected', got '$actual')."
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    & (Join-Path $stage 'install.ps1')
    Import-Module GitWorkflow -Force
    Install-Workstation -Extras:$Extras -NoNode:$NoNode -SkipPlugins:$SkipPlugins
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
