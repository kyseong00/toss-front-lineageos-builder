[CmdletBinding()]
param(
    [string]$ToolsRoot = (Join-Path $PSScriptRoot '.tools'),
    [string]$CygwinMirror = 'https://mirrors.kernel.org/sourceware/cygwin/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Message) {
    Write-Host "[tools] $Message" -ForegroundColor Cyan
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function New-AsciiPathMapping([string]$TargetPath) {
    $target = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
    $usedLetters = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpperInvariant() })
    foreach ($candidate in [char[]]'ZYXWVUTSRQPONMLKJIHGFED') {
        if ($usedLetters -contains [string]$candidate) { continue }
        $drive = "$($candidate):"
        & subst.exe $drive $target
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath "$drive\")) {
            throw "Failed to create a temporary path mapping for: $target"
        }
        return $drive
    }
    throw 'No unused drive letter is available for the temporary ASCII path mapping.'
}

function Get-RemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination
    )

    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source --fail --location --retry 3 --output $Destination $Url
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed: $Url"
        }
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
    }
}

function Install-PinnedFile {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Sha256,
        [Parameter(Mandatory)][string]$Directory
    )

    $destination = Join-Path $Directory $Name
    if (Test-Path -LiteralPath $destination) {
        if ((Get-Sha256 $destination) -eq $Sha256) {
            Write-Step "$Name already verified"
            return
        }
        throw "Existing tool has an unexpected hash: $destination"
    }

    Write-Step "Downloading $Name"
    Get-RemoteFile -Url $Url -Destination $destination
    $actual = Get-Sha256 $destination
    if ($actual -ne $Sha256) {
        Remove-Item -LiteralPath $destination -Force
        throw "Hash mismatch for $Name. Expected $Sha256, got $actual"
    }
}

$ToolsRoot = [IO.Path]::GetFullPath($ToolsRoot)
$LpRoot = Join-Path $ToolsRoot 'lp-tools-win'
$CygwinRoot = Join-Path $ToolsRoot 'cygwin'
$CacheRoot = Join-Path $ToolsRoot 'cache'
New-Item -ItemType Directory -Force -Path $LpRoot, $CacheRoot | Out-Null

$lpBase = 'https://github.com/thka2016/lpunpack_and_lpmake_cmake/releases/download/220922'
$lpFiles = @(
    @{ Name = 'cygwin1.dll'; Sha256 = '8BD44D91D09F2DC05646D071D2C465C2E9FDDC7313E7A343A3CDC01D58F10EB9' },
    @{ Name = 'lpmake.exe'; Sha256 = '0517FDCD4689534A5FD670FF4D89AB6BE2C41D1F6F7BAE694C5629E0F0225581' },
    @{ Name = 'lpunpack.exe'; Sha256 = 'CD873C9B42AC63BD91D8BE9B587747A8245C34ECCDCCFA17BE20F3C7BDE0231A' },
    @{ Name = 'simg2img.exe'; Sha256 = '2C3CEFD0E514FF751C4F63E66049DEB3A15C01A80CE07B3F69FA68F5E3017587' }
)

foreach ($item in $lpFiles) {
    Install-PinnedFile -Name $item.Name -Url "$lpBase/$($item.Name)" -Sha256 $item.Sha256 -Directory $LpRoot
}

$requiredCygwin = @(
    (Join-Path $CygwinRoot 'bin\xz.exe'),
    (Join-Path $CygwinRoot 'bin\lzip.exe'),
    (Join-Path $CygwinRoot 'usr\sbin\debugfs.exe'),
    (Join-Path $CygwinRoot 'usr\sbin\e2fsck.exe'),
    (Join-Path $CygwinRoot 'usr\sbin\resize2fs.exe')
)
$missingCygwin = @($requiredCygwin | Where-Object { -not (Test-Path -LiteralPath $_) })

if ($missingCygwin.Count -gt 0) {
    $setup = Join-Path $CacheRoot 'setup-x86_64.exe'
    Write-Step 'Downloading the signed Cygwin installer'
    Get-RemoteFile -Url 'https://cygwin.com/setup-x86_64.exe' -Destination $setup

    $signature = Get-AuthenticodeSignature -LiteralPath $setup
    if ($signature.Status -ne 'Valid') {
        throw "Cygwin installer signature is not valid: $($signature.Status)"
    }
    if (-not $signature.SignerCertificate -or $signature.SignerCertificate.Subject -notmatch 'CN=Jon Turney') {
        throw "Unexpected Cygwin installer signer: $($signature.SignerCertificate.Subject)"
    }

    Write-Step 'Installing a private Cygwin runtime (e2fsprogs, lzip, xz)'
    $cygwinCache = Join-Path $CacheRoot 'cygwin-packages'
    New-Item -ItemType Directory -Force -Path $cygwinCache | Out-Null
    $mappedDrive = New-AsciiPathMapping -TargetPath $ToolsRoot
    try {
        $setupArgs = @(
            '--quiet-mode', '--no-admin', '--no-shortcuts', '--no-write-registry',
            '--root', "$mappedDrive\cygwin",
            '--local-package-dir', "$mappedDrive\cache\cygwin-packages",
            '--site', $CygwinMirror,
            '--packages', 'e2fsprogs,lzip,xz'
        )
        $process = Start-Process -FilePath $setup -ArgumentList $setupArgs -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            throw "Cygwin setup failed with exit code $($process.ExitCode)"
        }
    } finally {
        & subst.exe $mappedDrive /D 2>$null
    }
}

$stillMissing = @($requiredCygwin | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($stillMissing.Count -gt 0) {
    throw "Required Cygwin tools are missing:`n$($stillMissing -join "`n")"
}

Write-Step "Ready: $ToolsRoot"
