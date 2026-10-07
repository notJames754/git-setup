#requires -Version 5.1

# =============================================================================
# Git USB Setup
#
# Run this script from the USB stick.
#
# Creates:
#
#   ./keys/<key-name>
#   ./keys/<key-name>.pub
#   ./.gitconfig
#   ./ssh.config
#
# The USB can later be used with git-setup
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir

$SshConfig = Join-Path $RootDir "ssh.config"
$GitConfig = Join-Path $RootDir ".gitconfig"
$KeysDir   = Join-Path $RootDir "keys"


function Die {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "Error: $Message" -ForegroundColor Red
    exit 1
}

function Ask-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    while ($true) {
        $answer = Read-Host "$Prompt [y/n]"

        switch ($answer.ToLowerInvariant()) {
            "y" {
                return $true
            }
            "yes" {
                return $true
            }
            "n" {
                return $false
            }
            "no" {
                return $false
            }
            default {
                Write-Host "Please answer y or n."
            }
        }
    }
}

function Write-SSH-Host {
    $SshHostEntry = @"

Host $HostName
    HostName $HostAddr
    User $HostUser
    IdentityFile %KEY_DIR%/$KeyName
    IdentitiesOnly yes
"@
    [System.IO.File]::AppendAllText(
        $SshConfig,
        $SshHostEntry,
        [System.Text.UTF8Encoding]::new($false)
    )
}


# Check dependencies
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "git is not installed or is not in PATH."
}

if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Die "ssh-keygen is not installed or is not in PATH."
}

# Create keys directory
New-Item -ItemType Directory -Path $KeysDir -Force | Out-Null


Write-Host ""
Write-Host "========================================"
Write-Host " Git USB Setup"
Write-Host "========================================"
Write-Host ""
Write-Host "USB directory:"
Write-Host "  $RootDir"
Write-Host ""
Write-Host "----------------------------------------"
Write-Host " Git configuration"
Write-Host "----------------------------------------"
Write-Host ""


if (Test-Path -LiteralPath $GitConfig -PathType Leaf) {

    Write-Host "A Git configuration already exists:"
    Write-Host "  $GitConfig"
    Write-Host ""

    if (Ask-YesNo "Replace it?") {
        Remove-Item -LiteralPath $GitConfig -Force
    }
    else {
        Write-Host "Keeping existing Git configuration."
    }
}

if (-not (Test-Path -LiteralPath $GitConfig -PathType Leaf)) {

    $UserGitConfig = Join-Path $HOME ".gitconfig"

    if (Test-Path -LiteralPath $UserGitConfig -PathType Leaf) {

        Write-Host ""
        Write-Host "Found your existing Git configuration:"
        Write-Host "  $UserGitConfig"
        Write-Host ""

        if (Ask-YesNo "Copy your existing .gitconfig to the USB?") {

            Copy-Item `
                -LiteralPath $UserGitConfig `
                -Destination $GitConfig `
                -Force

            Write-Host "Git configuration copied."
        }
    }
}

# If the user didn't copy an existing config, create one.
if (-not (Test-Path -LiteralPath $GitConfig -PathType Leaf)) {

    Write-Host ""
    Write-Host "Creating a new Git configuration."
    Write-Host ""

    do {
        $GitName = Read-Host "Git user.name"

        if ([string]::IsNullOrWhiteSpace($GitName)) {
            Write-Host "Name cannot be empty."
        }
    }
    while ([string]::IsNullOrWhiteSpace($GitName))

    do {
        $GitEmail = Read-Host "Git user.email"

        if ([string]::IsNullOrWhiteSpace($GitEmail)) {
            Write-Host "Email cannot be empty."
        }
    }
    while ([string]::IsNullOrWhiteSpace($GitEmail))

    $GitConfigContent = @"
[user]
    name = $GitName
    email = $GitEmail
"@

    Set-Content `
        -LiteralPath $GitConfig `
        -Value $GitConfigContent `
        -Encoding UTF8

    Write-Host ""
    Write-Host "Created:"
    Write-Host "  $GitConfig"
}


Write-Host ""
Write-Host "----------------------------------------"
Write-Host " SSH configuration"
Write-Host "----------------------------------------"
Write-Host ""

if (Test-Path -LiteralPath $SshConfig -PathType Leaf) {

    Write-Host "An SSH configuration already exists:"
    Write-Host "  $SshConfig"
    Write-Host ""

    if (-not (Ask-YesNo "Replace it?")) {
        Write-Host "Keeping existing SSH configuration."
        Write-Host ""
        Write-Host "Setup complete."
        exit 0
    }

    Remove-Item -LiteralPath $SshConfig -Force
}

# Create SSH configuration header.
$SshHeader = @'
# ============================================================================
# Git USB SSH configuration
#
# Paths are relative placeholders. git-setup replaces %KEY_DIR% with
# the keys directory when the environment is started.
# ============================================================================

'@

[System.IO.File]::WriteAllText(
    $SshConfig,
    $SshHeader,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "You can now configure multiple Git hosts."
Write-Host ""
Write-Host "For each host you can:"
Write-Host ""
Write-Host "  Host name       The hostname used in the Git URL"
Write-Host "                  e.g. github.com"
Write-Host ""
Write-Host "  Key name        Filename stored in ./keys/"
Write-Host "                  e.g. github"
Write-Host ""
Write-Host "Examples:"
Write-Host ""
Write-Host "  git@github.com:username/repository.git"
Write-Host "  git@gitlab.com:username/repository.git"
Write-Host "  git@git.company.com:project/repository.git"
Write-Host ""


while ($true) {

    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "Add SSH host"
    Write-Host "----------------------------------------"
    Write-Host ""

    $HostName = Read-Host "Host name (empty to finish)"

    if ([string]::IsNullOrEmpty($HostName)) {
        break
    }

    # Basic validation.
    if ($HostName -match "\s") {
        Write-Host "Host name cannot contain spaces."
        continue
    }

    $HostAddr = Read-Host "Host addr ($HostName)"

    if ([string]::IsNullOrEmpty($HostAddr)) {
        $HostAddr = $HostName
    }

    if ($HostAddr -match "\s") {
        Write-Host "Host addr cannot contain spaces."
        continue
    }

    $HostUser = Read-Host "Host user (git)"

    if ([string]::IsNullOrEmpty($HostUser)) {
        $HostUser = "git"
    }

    if ($HostUser -match "\s") {
        Write-Host "Host user cannot contain spaces."
        continue
    }

    $KeyName = Read-Host "SSH key name [$HostName]"

    if ([string]::IsNullOrEmpty($KeyName)) {
        $KeyName = $HostName
    }

    # Keep key names filesystem-safe.
    #
    # Windows filenames cannot contain:
    #   \ / : * ? " < > |
    #
    if ($KeyName -match '[\\/:*?"<>|]') {
        Write-Host "Key name contains invalid filename characters."
        continue
    }

    $KeyFile = Join-Path $KeysDir $KeyName
    $PublicKey = "$KeyFile.pub"


    # Existing key
    if (Test-Path -LiteralPath $KeyFile -PathType Leaf) {

        Write-Host ""
        Write-Host "A private key already exists:"
        Write-Host "  $KeyFile"
        Write-Host ""

        if (Ask-YesNo "Use this existing key?") {
            Write-SSH-Host
            continue
        }
    }
    else {

        Write-Host ""
        Write-Host "No key found for $HostName."
        Write-Host ""
    }


    if (Ask-YesNo "Generate a new ED25519 key?") {

        Write-Host ""
        Write-Host "Generating:"
        Write-Host "  $KeyFile"
        Write-Host ""

        & ssh-keygen `
            -t ed25519 `
            -f $KeyFile `
            -C " "

        if ($LASTEXITCODE -ne 0) {
            Die "ssh-keygen failed."
        }

        Write-Host ""
        Write-Host "Key generated."
    }
    else {

        Write-Host ""
        Write-Host "You can copy an existing private key to:"
        Write-Host "  $KeyFile"
        Write-Host ""
        Write-SSH-Host
        continue
    }


    if (-not (Test-Path -LiteralPath $PublicKey -PathType Leaf)) {

        Write-Host ""
        Write-Host "Public key not found."
        Write-Host "Generating it from the private key..."

        & ssh-keygen `
            -y `
            -f $KeyFile |
            Set-Content -LiteralPath $PublicKey -Encoding ASCII

        if ($LASTEXITCODE -ne 0) {
            Die "Unable to generate the public key."
        }

        Write-Host "Public key generated:"
        Write-Host "  $PublicKey"
    }

    Write-SSH-Host

    Write-Host ""
    Write-Host "Added:"
    Write-Host "  Host: $HostName"
    Write-Host "  Key : $KeyName"
    Write-Host ""
    Write-Host "Public key:"
    Write-Host ""

    Get-Content -LiteralPath $PublicKey

    Write-Host ""
    Write-Host "Add this public key to the corresponding Git provider."
    Write-Host ""

    if (-not (Ask-YesNo "Configure another Git host?")) {
        break
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host " Setup complete"
Write-Host "========================================"
Write-Host ""

Write-Host "USB directory:"
Write-Host "  $RootDir"
Write-Host ""

Write-Host "Git configuration:"
Write-Host "  $GitConfig"
Write-Host ""

Write-Host "SSH configuration:"
Write-Host "  $SshConfig"
Write-Host ""

Write-Host "SSH keys:"

Get-ChildItem `
    -LiteralPath $KeysDir `
    -File `
    -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host "  $($_.Name)"
    }

Write-Host ""
Write-Host "Configured hosts:"

Get-Content -LiteralPath $SshConfig |
    Where-Object { $_ -match '^Host ' } |
    ForEach-Object {
        Write-Host "  $_"
    }

Write-Host ""
Write-Host "========================================"
Write-Host ""
Write-Host "The USB is ready."
Write-Host ""
Write-Host "Use git-setup to start the isolated Git environment."
Write-Host ""