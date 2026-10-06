$ErrorActionPreference = "Stop"


$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir

$SshConfig = Join-Path $RootDir "ssh.config"
$GitConfig = Join-Path $RootDir ".gitconfig"
$KeysDir   = Join-Path $RootDir "keys"


if (-not (Test-Path -LiteralPath $SshConfig -PathType Leaf)) {
    Write-Host "Error: SSH config not found:"
    Write-Host "  $SshConfig"
    exit 1
}

if (-not (Test-Path -LiteralPath $GitConfig -PathType Leaf)) {
    Write-Host "Error: Git config not found:"
    Write-Host "  $GitConfig"
    exit 1
}

if (-not (Test-Path -LiteralPath $KeysDir -PathType Container)) {
    Write-Host "Error: keys directory not found:"
    Write-Host "  $KeysDir"
    exit 1
}


$TempDir = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ([System.IO.Path]::GetRandomFileName())

$TempSshConfig = Join-Path $TempDir "ssh-config"

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    # Convert the Windows key directory to a format SSH understands
    # OpenSSH accepts forward slashes on Windows
    $KeyDirForSsh = $KeysDir -replace '\\', '/'


    $SshConfigContent = Get-Content `
        -LiteralPath $SshConfig `
        -Raw

    $SshConfigContent = $SshConfigContent.Replace(
        "%KEY_DIR%",
        $KeyDirForSsh
    )

    Set-Content `
        -LiteralPath $TempSshConfig `
        -Value $SshConfigContent `
        -Encoding UTF8 `
        -NoNewline


    $env:GIT_SSH_COMMAND = 'ssh -F "' + $TempSshConfig + '"'
    $env:GIT_CONFIG_GLOBAL = $GitConfig


    Write-Host ""
    Write-Host "========================================"
    Write-Host " Git USB environment"
    Write-Host "========================================"
    Write-Host ""
    Write-Host " Git config : $GitConfig"
    Write-Host " SSH config : $SshConfig"
    Write-Host ""
    Write-Host "SSH keys:"

    Get-Content -LiteralPath $TempSshConfig |
        Where-Object { $_ -match '^\s*IdentityFile\s+' } |
        ForEach-Object {
            $_ -replace '^\s*IdentityFile', '  IdentityFile'
        }

    Write-Host ""
    Write-Host "Type 'exit' when finished."
    Write-Host ""

    & powershell.exe -NoLogo -NoExit
}
finally {
    if (Test-Path -LiteralPath $TempDir) {
        Remove-Item `
            -LiteralPath $TempDir `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Remove-Item Env:GIT_SSH_COMMAND `
        -ErrorAction SilentlyContinue

    Remove-Item Env:GIT_CONFIG_GLOBAL `
        -ErrorAction SilentlyContinue
}