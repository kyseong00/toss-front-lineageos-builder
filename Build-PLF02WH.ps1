[CmdletBinding()]
param(
    [string]$StockSuper,
    [string]$LineageImage,
    [string]$OpenGApps,
    [string]$OutputImage,
    [string]$ToolsRoot,
    [string]$LzipPath,
    [switch]$DownloadInputs,
    [switch]$AcceptOpenGAppsPersonalUse,
    [switch]$KeepWork,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$SourceInfo = [ordered]@{
    Lineage = [ordered]@{
        Name = 'lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img.xz'
        Url = 'https://sourceforge.net/projects/andyyan-gsi/files/lineage-18.x/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img.xz/download'
        Sha256 = 'EE126763EE3A03518D829C9AE08204A535342C062936B3124BD0E93E623FF941'
    }
    OpenGApps = [ordered]@{
        Name = 'open_gapps-arm64-11.0-pico-20220503.zip'
        Url = 'https://sourceforge.net/projects/opengapps/files/arm64/20220503/open_gapps-arm64-11.0-pico-20220503.zip/download'
        Sha256 = '11C4FF4DB8CE7A7876F7D30BEC46D853E52B82CC702AA717B421A2602988112B'
    }
}

$KnownStock = [ordered]@{
    SuperSize = [int64]2147483648
    SuperSha256 = '99F9431251BA4C6FE706A90A4F8E3B8610690CB422019112BCE98BD122A1B080'
    VendorSize = [int64]220258304
    VendorSha256 = '46D911204C94AB5360CAB2D6FF3C78A1E2CD07F8AFAC15FFC6BA636C4063B736'
    OdmSize = [int64]585728
    OdmSha256 = '3E42C410A1A1F2FA174ACC8B2FB44E0DA24857A4BEA151733C9461E449CC7CE9'
}

$Layout = [ordered]@{
    SuperSize = [int64]2147483648
    GroupName = 'rockchip_dynamic_partitions'
    GroupSize = [int64]2143289344
    SystemSize = [int64]1922445312
    SystemBlocks = 469347
    VendorSize = [int64]220258304
    OdmSize = [int64]585728
}

$RemovePaths = @(
    '/system/product/app/Backgrounds',
    '/system/product/app/DeskClock',
    '/system/product/app/Etar',
    '/system/product/app/ExactCalculator',
    '/system/product/app/Jelly',
    '/system/product/app/PhotoTable',
    '/system/product/app/Recorder',
    '/system/product/app/messaging',
    '/system/product/priv-app/Contacts',
    '/system/product/priv-app/Dialer',
    '/system/product/priv-app/Eleven',
    '/system/system_ext/priv-app/Camera2',
    '/system/system_ext/priv-app/Gallery2',
    '/system/system_ext/priv-app/ThemePicker',
    '/system/priv-app/AudioFX',
    '/system/app/BasicDreams',
    '/system/app/LiveWallpapersPicker',
    '/system/app/PrintRecommendationService',
    '/system/app/PrintSpooler',
    '/system/app/Traceur',
    '/system/priv-app/BuiltInPrintService',
    '/system/priv-app/DynamicSystemInstallationService',
    '/system/priv-app/Seedvault',
    '/system/system_ext/priv-app/EmergencyInfo',
    '/system/system_ext/priv-app/QuickAccessWallet'
)

function Write-Step([string]$Message) {
    Write-Host "[build] $Message" -ForegroundColor Cyan
}

function Get-FullPath([string]$Path, [string]$Base = (Get-Location).Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-Hash {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected) {
        throw "$Label hash mismatch.`nExpected: $Expected`nActual:   $actual`nFile: $Path"
    }
    Write-Step "$Label hash verified"
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int[]]$AllowedExitCodes = @(0)
    )
    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if ($AllowedExitCodes -notcontains $exitCode) {
        throw "Command failed ($exitCode): $FilePath $($ArgumentList -join ' ')"
    }
}

function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int[]]$AllowedExitCodes = @(0)
    )
    $output = @(& $FilePath @ArgumentList 2>&1)
    $exitCode = $LASTEXITCODE
    if ($AllowedExitCodes -notcontains $exitCode) {
        throw "Command failed ($exitCode): $FilePath $($ArgumentList -join ' ')`n$($output -join "`n")"
    }
    return $output
}

function New-AsciiPathMapping {
    param(
        [Parameter(Mandatory)][string]$TargetPath
    )
    $target = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
    foreach ($mapping in $script:AsciiPathMappings) {
        if ($mapping.Target -eq $target) {
            return $mapping.Root
        }
    }

    $usedLetters = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpperInvariant() })
    $letter = $null
    foreach ($candidate in [char[]]'ZYXWVUTSRQPONMLKJIHGFED') {
        if ($usedLetters -notcontains [string]$candidate) {
            $letter = [string]$candidate
            break
        }
    }
    if (-not $letter) {
        throw 'No unused drive letter is available for the temporary ASCII path mapping.'
    }

    $drive = "${letter}:"
    & subst.exe $drive $target
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath "$drive\")) {
        throw "Failed to create a temporary path mapping for: $target"
    }
    $mapping = [pscustomobject]@{ Target = $target; Root = "$drive\"; Drive = $drive }
    $script:AsciiPathMappings.Add($mapping) | Out-Null
    return $mapping.Root
}

function Convert-ToToolPath {
    param(
        [Parameter(Mandatory)][string]$WindowsPath
    )
    $fullPath = [IO.Path]::GetFullPath($WindowsPath)
    foreach ($mapping in @($script:AsciiPathMappings | Sort-Object { $_.Target.Length } -Descending)) {
        if ($fullPath -eq $mapping.Target) {
            return $mapping.Root.TrimEnd('\')
        }
        $prefix = $mapping.Target.TrimEnd('\') + '\'
        if ($fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $relative = $fullPath.Substring($prefix.Length)
            return Join-Path $mapping.Root $relative
        }
    }

    $parent = Split-Path -Parent $fullPath
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Cannot create an ASCII path mapping for: $fullPath"
    }
    $mappedParent = New-AsciiPathMapping -TargetPath $parent
    return Join-Path $mappedParent ([IO.Path]::GetFileName($fullPath))
}

function Get-RemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination
    )
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
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

function Test-AndroidSparse([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $bytes = New-Object byte[] 4
        if ($stream.Read($bytes, 0, 4) -ne 4) { return $false }
        return $bytes[0] -eq 0x3A -and $bytes[1] -eq 0xFF -and $bytes[2] -eq 0x26 -and $bytes[3] -eq 0xED
    } finally {
        $stream.Dispose()
    }
}

function Test-Ext4Image([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 1082) { return $false }
        $stream.Seek(1080, [IO.SeekOrigin]::Begin) | Out-Null
        $bytes = New-Object byte[] 2
        if ($stream.Read($bytes, 0, 2) -ne 2) { return $false }
        return $bytes[0] -eq 0x53 -and $bytes[1] -eq 0xEF
    } finally {
        $stream.Dispose()
    }
}

function Test-DebugFsPath {
    param([string]$DebugFs, [string]$Image, [string]$ImagePath)
    $text = (Invoke-NativeCapture -FilePath $DebugFs -ArgumentList @('-R', "stat $ImagePath", $Image)) -join "`n"
    return $text -match 'Inode:\s+[0-9]+'
}

function Get-DebugFsEntries {
    param([string]$DebugFs, [string]$Image, [string]$Directory)
    $lines = Invoke-NativeCapture -FilePath $DebugFs -ArgumentList @('-R', "ls -p $Directory", $Image)
    $entries = @()
    foreach ($lineObject in $lines) {
        $line = [string]$lineObject
        if (-not $line.StartsWith('/')) { continue }
        $fields = $line.Split('/')
        if ($fields.Count -lt 7) { continue }
        $name = $fields[5]
        if ($name -eq '.' -or $name -eq '..' -or [string]::IsNullOrWhiteSpace($name)) { continue }
        $entries += [pscustomobject]@{ Mode = $fields[2]; Name = $name }
    }
    return $entries
}

function Add-RemoveTreeCommands {
    param(
        [string]$DebugFs,
        [string]$Image,
        [string]$ImagePath,
        [System.Collections.Generic.List[string]]$Commands
    )
    foreach ($entry in (Get-DebugFsEntries -DebugFs $DebugFs -Image $Image -Directory $ImagePath)) {
        $child = "$($ImagePath.TrimEnd('/'))/$($entry.Name)"
        if ($entry.Mode.StartsWith('04')) {
            Add-RemoveTreeCommands -DebugFs $DebugFs -Image $Image -ImagePath $child -Commands $Commands
            $Commands.Add("rmdir $child")
        } else {
            $Commands.Add("rm $child")
        }
    }
}

function Add-InodeMetadata {
    param(
        [System.Collections.Generic.List[string]]$Commands,
        [string]$Name,
        [string]$Mode,
        [string]$SelinuxContext
    )
    $Commands.Add("sif $Name mode $Mode")
    $Commands.Add("sif $Name uid 0")
    $Commands.Add("sif $Name gid 0")
    $Commands.Add("ea_set $Name security.selinux $SelinuxContext")
}

function Get-ImageParent([string]$Path) {
    $index = $Path.LastIndexOf('/')
    if ($index -le 0) { return '/' }
    return $Path.Substring(0, $index)
}

function Get-ImageName([string]$Path) {
    $index = $Path.LastIndexOf('/')
    return $Path.Substring($index + 1)
}

function Copy-TreeContents {
    param([string]$Source, [string]$Destination)
    $sourceFull = [IO.Path]::GetFullPath($Source).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $sourceFull -PathType Container)) {
        throw "Missing extracted OpenGApps directory: $sourceFull"
    }
    foreach ($file in Get-ChildItem -LiteralPath $sourceFull -Recurse -File) {
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $Destination $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
}

function Assert-FileSize([string]$Path, [int64]$Expected, [string]$Label) {
    $actual = (Get-Item -LiteralPath $Path).Length
    if ($actual -ne $Expected) {
        throw "$Label size mismatch. Expected $Expected bytes, got $actual bytes"
    }
}

if ([string]::IsNullOrWhiteSpace($StockSuper)) {
    $StockSuper = Join-Path $PSScriptRoot 'input\stock-super.img'
}
if ([string]::IsNullOrWhiteSpace($LineageImage)) {
    $LineageImage = Join-Path $PSScriptRoot "input\$($SourceInfo.Lineage.Name)"
}
if ([string]::IsNullOrWhiteSpace($OpenGApps)) {
    $OpenGApps = Join-Path $PSScriptRoot "input\$($SourceInfo.OpenGApps.Name)"
}
if ([string]::IsNullOrWhiteSpace($OutputImage)) {
    $OutputImage = Join-Path $PSScriptRoot 'output\super_PLF02WH_lineage18.1_gapps_pico.img'
}
if ([string]::IsNullOrWhiteSpace($ToolsRoot)) {
    $ToolsRoot = Join-Path $PSScriptRoot '.tools'
}

$StockSuper = Get-FullPath $StockSuper
$LineageImage = Get-FullPath $LineageImage
$OpenGApps = Get-FullPath $OpenGApps
$OutputImage = Get-FullPath $OutputImage
$ToolsRoot = Get-FullPath $ToolsRoot

if (-not $AcceptOpenGAppsPersonalUse) {
    throw 'OpenGApps prebuilt packages are personal-use only and may not be publicly mirrored. Re-run with -AcceptOpenGAppsPersonalUse after reading THIRD_PARTY_NOTICES.md.'
}

if ($DownloadInputs) {
    if (-not (Test-Path -LiteralPath $LineageImage)) {
        Write-Step "Downloading $($SourceInfo.Lineage.Name) from its original SourceForge project"
        Get-RemoteFile -Url $SourceInfo.Lineage.Url -Destination $LineageImage
    }
    if (-not (Test-Path -LiteralPath $OpenGApps)) {
        Write-Step "Downloading $($SourceInfo.OpenGApps.Name) from OpenGApps SourceForge"
        Get-RemoteFile -Url $SourceInfo.OpenGApps.Url -Destination $OpenGApps
    }
}

foreach ($requiredInput in @($StockSuper, $LineageImage, $OpenGApps)) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required input is missing: $requiredInput"
    }
}

Assert-FileSize -Path $StockSuper -Expected $KnownStock.SuperSize -Label 'stock super'
Assert-Hash -Path $StockSuper -Expected $KnownStock.SuperSha256 -Label 'known PLF02WH stock super'
Assert-Hash -Path $LineageImage -Expected $SourceInfo.Lineage.Sha256 -Label 'LineageOS GSI'
Assert-Hash -Path $OpenGApps -Expected $SourceInfo.OpenGApps.Sha256 -Label 'OpenGApps Pico'

$setupScript = Join-Path $PSScriptRoot 'Setup-Tools.ps1'
$lpRoot = Join-Path $ToolsRoot 'lp-tools-win'
$cygwinRoot = Join-Path $ToolsRoot 'cygwin'
$tools = [ordered]@{
    LpMake = Join-Path $lpRoot 'lpmake.exe'
    LpUnpack = Join-Path $lpRoot 'lpunpack.exe'
    Simg2Img = Join-Path $lpRoot 'simg2img.exe'
    Cygpath = Join-Path $cygwinRoot 'bin\cygpath.exe'
    Xz = Join-Path $cygwinRoot 'bin\xz.exe'
    Lzip = if ([string]::IsNullOrWhiteSpace($LzipPath)) { Join-Path $cygwinRoot 'bin\lzip.exe' } else { Get-FullPath $LzipPath }
    DebugFs = Join-Path $cygwinRoot 'usr\sbin\debugfs.exe'
    E2Fsck = Join-Path $cygwinRoot 'usr\sbin\e2fsck.exe'
    Resize2Fs = Join-Path $cygwinRoot 'usr\sbin\resize2fs.exe'
}
$missingTools = @($tools.Values | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missingTools.Count -gt 0) {
    Write-Step 'Required tools are missing; running Setup-Tools.ps1'
    & $setupScript -ToolsRoot $ToolsRoot
}
$missingTools = @($tools.Values | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missingTools.Count -gt 0) {
    throw "Tools are still missing:`n$($missingTools -join "`n")"
}
$windowsTar = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $windowsTar -PathType Leaf)) {
    throw 'Windows tar.exe was not found. Windows 10 or 11 is required.'
}

$outputParent = Split-Path -Parent $OutputImage
New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
if (Test-Path -LiteralPath $OutputImage) {
    if (-not $Force) {
        throw "Output already exists. Use -Force to replace it: $OutputImage"
    }
    Remove-Item -LiteralPath $OutputImage -Force
}

$driveRoot = [IO.Path]::GetPathRoot($OutputImage)
$drive = New-Object IO.DriveInfo($driveRoot)
$minimumFree = [int64](14GB)
if ($drive.AvailableFreeSpace -lt $minimumFree) {
    throw "At least 14 GiB of free space is required on $driveRoot"
}

$workBase = Join-Path $PSScriptRoot '.work'
$workId = [Guid]::NewGuid().ToString('N')
$workRoot = Join-Path $workBase $workId
$workRelative = ".work/$workId"
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
$success = $false
$script:AsciiPathMappings = New-Object 'System.Collections.Generic.List[object]'
$projectToolRoot = $null

$oldPath = $env:PATH
$env:PATH = (Join-Path $cygwinRoot 'bin') + [IO.Path]::PathSeparator + $oldPath

try {
    $projectToolRoot = New-AsciiPathMapping -TargetPath $PSScriptRoot
    Write-Step 'Unpacking stock super and checking vendor/odm'
    $stockParts = Join-Path $workRoot 'stock-parts'
    New-Item -ItemType Directory -Force -Path $stockParts | Out-Null
    $stockSuperCyg = Convert-ToToolPath -WindowsPath $StockSuper
    $stockPartsCyg = Convert-ToToolPath -WindowsPath $stockParts
    Invoke-Native -FilePath $tools.LpUnpack -ArgumentList @($stockSuperCyg, $stockPartsCyg)
    $stockVendor = Join-Path $stockParts 'vendor.img'
    $stockOdm = Join-Path $stockParts 'odm.img'
    Assert-FileSize -Path $stockVendor -Expected $KnownStock.VendorSize -Label 'stock vendor'
    Assert-Hash -Path $stockVendor -Expected $KnownStock.VendorSha256 -Label 'stock vendor'
    Assert-FileSize -Path $stockOdm -Expected $KnownStock.OdmSize -Label 'stock odm'
    Assert-Hash -Path $stockOdm -Expected $KnownStock.OdmSha256 -Label 'stock odm'

    Write-Step 'Preparing raw LineageOS system image'
    $lineageLocal = Join-Path $workRoot $SourceInfo.Lineage.Name
    Copy-Item -LiteralPath $LineageImage -Destination $lineageLocal
    if ($lineageLocal.EndsWith('.xz', [StringComparison]::OrdinalIgnoreCase)) {
        $lineageLocalCyg = Convert-ToToolPath -WindowsPath $lineageLocal
        Invoke-Native -FilePath $tools.Xz -ArgumentList @('-d', '-k', '-f', $lineageLocalCyg)
        $lineageLocal = $lineageLocal.Substring(0, $lineageLocal.Length - 3)
    }
    $systemImage = Join-Path $workRoot 'system-lineage.img'
    if (Test-AndroidSparse $lineageLocal) {
        Invoke-Native -FilePath $tools.Simg2Img -ArgumentList @(
            (Convert-ToToolPath -WindowsPath $lineageLocal),
            (Convert-ToToolPath -WindowsPath $systemImage)
        )
    } else {
        Copy-Item -LiteralPath $lineageLocal -Destination $systemImage
    }
    if (-not (Test-Ext4Image $systemImage)) {
        throw 'The LineageOS input did not produce a raw ext4 filesystem image.'
    }
    $systemImageCyg = Convert-ToToolPath -WindowsPath $systemImage
    Invoke-Native -FilePath $tools.E2Fsck -ArgumentList @('-fy', $systemImageCyg) -AllowedExitCodes @(0, 1, 2)
    Invoke-Native -FilePath $tools.Resize2Fs -ArgumentList @('-f', $systemImageCyg, [string]$Layout.SystemBlocks)
    Assert-FileSize -Path $systemImage -Expected $Layout.SystemSize -Label 'resized system'

    Write-Step 'Removing nonessential LineageOS applications'
    $removeCommands = New-Object 'System.Collections.Generic.List[string]'
    foreach ($imagePath in $RemovePaths) {
        if (-not (Test-DebugFsPath -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $imagePath)) {
            throw "Expected path is missing from the pinned GSI: $imagePath"
        }
        Add-RemoveTreeCommands -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $imagePath -Commands $removeCommands
        $removeCommands.Add("rmdir $imagePath")
    }
    $removeFile = Join-Path $workRoot 'remove-apps.debugfs'
    [IO.File]::WriteAllLines($removeFile, $removeCommands, [Text.Encoding]::ASCII)
    Invoke-Native -FilePath $tools.DebugFs -ArgumentList @(
        '-w', '-f',
        (Convert-ToToolPath -WindowsPath $removeFile),
        $systemImageCyg
    )
    foreach ($imagePath in $RemovePaths) {
        if (Test-DebugFsPath -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $imagePath) {
            throw "Failed to remove GSI path: $imagePath"
        }
    }

    Write-Step 'Extracting the selected OpenGApps Pico components'
    $gappsZipRoot = Join-Path $workRoot 'gapps-zip'
    $gappsExtract = Join-Path $workRoot 'gapps-extracted'
    $gappsTree = Join-Path $workRoot 'gapps-tree'
    New-Item -ItemType Directory -Force -Path $gappsZipRoot, $gappsExtract, $gappsTree | Out-Null
    Expand-Archive -LiteralPath $OpenGApps -DestinationPath $gappsZipRoot -Force
    $archives = @(
        'defaultetc-common', 'defaultframework-common', 'gmscore-arm64',
        'googleonetimeinitializer-all', 'googlepartnersetup-all',
        'gsfcore-all', 'vending-arm64'
    )
    foreach ($archiveName in $archives) {
        $archiveLz = Join-Path $gappsZipRoot "Core\$archiveName.tar.lz"
        if (-not (Test-Path -LiteralPath $archiveLz)) {
            throw "Missing OpenGApps component: Core/$archiveName.tar.lz"
        }
        Invoke-Native -FilePath $tools.Lzip -ArgumentList @(
            '-d', '-k', '-f',
            (Convert-ToToolPath -WindowsPath $archiveLz)
        )
        $archiveTar = $archiveLz.Substring(0, $archiveLz.Length - 3)
        Invoke-Native -FilePath $windowsTar -ArgumentList @(
            '-xf', (Convert-ToToolPath -WindowsPath $archiveTar),
            '-C', (Convert-ToToolPath -WindowsPath $gappsExtract)
        )
    }

    Copy-TreeContents -Source (Join-Path $gappsExtract 'defaultetc-common\common\etc') -Destination (Join-Path $gappsTree 'etc')
    Copy-TreeContents -Source (Join-Path $gappsExtract 'defaultframework-common\common') -Destination $gappsTree
    Copy-TreeContents -Source (Join-Path $gappsExtract 'gmscore-arm64\nodpi') -Destination $gappsTree
    Copy-TreeContents -Source (Join-Path $gappsExtract 'googleonetimeinitializer-all\nodpi') -Destination $gappsTree
    Copy-TreeContents -Source (Join-Path $gappsExtract 'googlepartnersetup-all\nodpi') -Destination $gappsTree
    Copy-TreeContents -Source (Join-Path $gappsExtract 'gsfcore-all\nodpi') -Destination $gappsTree
    Copy-TreeContents -Source (Join-Path $gappsExtract 'vending-arm64\nodpi') -Destination $gappsTree

    $expectedGapps = @(
        'priv-app\Phonesky\Phonesky.apk',
        'priv-app\PrebuiltGmsCore\PrebuiltGmsCore.apk',
        'priv-app\GoogleServicesFramework\GoogleServicesFramework.apk'
    )
    foreach ($relative in $expectedGapps) {
        if (-not (Test-Path -LiteralPath (Join-Path $gappsTree $relative))) {
            throw "Expected GApps payload is missing: $relative"
        }
    }

    Write-Step 'Injecting Google services into the system image'
    $addCommands = New-Object 'System.Collections.Generic.List[string]'
    $treeRootFull = [IO.Path]::GetFullPath($gappsTree).TrimEnd('\')
    $directories = @(Get-ChildItem -LiteralPath $gappsTree -Recurse -Directory | Sort-Object @{ Expression = { $_.FullName.Split('\').Count } }, FullName)
    foreach ($directory in $directories) {
        $relative = $directory.FullName.Substring($treeRootFull.Length).TrimStart('\').Replace('\', '/')
        $destination = "/system/$relative"
        if (-not (Test-DebugFsPath -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $destination)) {
            $parent = Get-ImageParent $destination
            $name = Get-ImageName $destination
            $addCommands.Add("cd $parent")
            $addCommands.Add("mkdir $name")
            Add-InodeMetadata -Commands $addCommands -Name $name -Mode '040755' -SelinuxContext 'u:object_r:system_file:s0'
        }
    }
    foreach ($file in (Get-ChildItem -LiteralPath $gappsTree -Recurse -File | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($treeRootFull.Length).TrimStart('\').Replace('\', '/')
        $destination = "/system/$relative"
        $parent = Get-ImageParent $destination
        $name = Get-ImageName $destination
        $hostRelative = $file.FullName.Substring(([IO.Path]::GetFullPath($PSScriptRoot)).TrimEnd('\').Length).TrimStart('\').Replace('\', '/')
        $addCommands.Add("cd $parent")
        if (Test-DebugFsPath -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $destination) {
            $addCommands.Add("rm $name")
        }
        $addCommands.Add("write $hostRelative $name")
        Add-InodeMetadata -Commands $addCommands -Name $name -Mode '0100644' -SelinuxContext 'u:object_r:system_file:s0'
    }
    $addFile = Join-Path $workRoot 'add-gapps.debugfs'
    [IO.File]::WriteAllLines($addFile, $addCommands, [Text.Encoding]::ASCII)
    Push-Location $projectToolRoot
    try {
        Invoke-Native -FilePath $tools.DebugFs -ArgumentList @(
            '-w', '-f',
            (Convert-ToToolPath -WindowsPath $addFile),
            $systemImageCyg
        )
    } finally {
        Pop-Location
    }
    foreach ($imagePath in @(
        '/system/priv-app/Phonesky/Phonesky.apk',
        '/system/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk',
        '/system/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk'
    )) {
        if (-not (Test-DebugFsPath -DebugFs $tools.DebugFs -Image $systemImageCyg -ImagePath $imagePath)) {
            throw "GApps injection verification failed: $imagePath"
        }
    }
    Invoke-Native -FilePath $tools.E2Fsck -ArgumentList @('-fy', $systemImageCyg) -AllowedExitCodes @(0, 1, 2)

    Write-Step 'Patching the stock vendor fstab for the GSI'
    $vendorImage = Join-Path $workRoot 'vendor-lineage.img'
    Copy-Item -LiteralPath $stockVendor -Destination $vendorImage
    $vendorImageCyg = Convert-ToToolPath -WindowsPath $vendorImage
    $vendorCommands = @(
        'cd /etc',
        'rm fstab.rk30board',
        'write patches/fstab.rk30board fstab.rk30board',
        'sif fstab.rk30board mode 0100644',
        'sif fstab.rk30board uid 0',
        'sif fstab.rk30board gid 0',
        'ea_set fstab.rk30board security.selinux u:object_r:vendor_configs_file:s0'
    )
    $vendorCommandFile = Join-Path $workRoot 'patch-vendor.debugfs'
    [IO.File]::WriteAllLines($vendorCommandFile, $vendorCommands, [Text.Encoding]::ASCII)
    Push-Location $projectToolRoot
    try {
        Invoke-Native -FilePath $tools.DebugFs -ArgumentList @(
            '-w', '-f',
            (Convert-ToToolPath -WindowsPath $vendorCommandFile),
            $vendorImageCyg
        )
    } finally {
        Pop-Location
    }
    $fstabText = (Invoke-NativeCapture -FilePath $tools.DebugFs -ArgumentList @('-R', 'cat /etc/fstab.rk30board', $vendorImageCyg)) -join "`n"
    $fstabConfig = (($fstabText -split "`r?`n") | Where-Object {
        -not $_.TrimStart().StartsWith('#')
    }) -join "`n"
    if ($fstabConfig -match '(?m)^product\s+/product' -or
        $fstabConfig -match '(?m)^system_ext\s+/system_ext' -or
        $fstabConfig -match 'dirsync' -or
        $fstabConfig -match 'fileencryption=') {
        throw 'Vendor fstab verification failed.'
    }
    if ($fstabConfig -notmatch '/dev/block/by-name/userdata\s+/data\s+ext4') {
        throw 'The patched vendor fstab has no userdata entry.'
    }
    Invoke-Native -FilePath $tools.E2Fsck -ArgumentList @('-fy', $vendorImageCyg) -AllowedExitCodes @(0, 1, 2)

    Write-Step 'Building the 2 GiB PLF02WH super image'
    $candidateSuper = Join-Path $workRoot 'super-candidate.img'
    $lpArgs = @(
        '--metadata-size', '65536',
        '--super-name', 'super',
        '--metadata-slots', '2',
        '--device', "super:$($Layout.SuperSize)",
        '--group', "$($Layout.GroupName):$($Layout.GroupSize)",
        '--partition', "system:readonly:$($Layout.SystemSize):$($Layout.GroupName)",
        '--image', "system=$(Convert-ToToolPath -WindowsPath $systemImage)",
        '--partition', "vendor:readonly:$($Layout.VendorSize):$($Layout.GroupName)",
        '--image', "vendor=$(Convert-ToToolPath -WindowsPath $vendorImage)",
        '--partition', "odm:readonly:$($Layout.OdmSize):$($Layout.GroupName)",
        '--image', "odm=$(Convert-ToToolPath -WindowsPath $stockOdm)",
        '--output', (Convert-ToToolPath -WindowsPath $candidateSuper)
    )
    Invoke-Native -FilePath $tools.LpMake -ArgumentList $lpArgs
    Assert-FileSize -Path $candidateSuper -Expected $Layout.SuperSize -Label 'candidate super'

    Write-Step 'Unpacking the result and verifying every logical partition'
    $verifyRoot = Join-Path $workRoot 'verify-super'
    New-Item -ItemType Directory -Force -Path $verifyRoot | Out-Null
    Invoke-Native -FilePath $tools.LpUnpack -ArgumentList @(
        (Convert-ToToolPath -WindowsPath $candidateSuper),
        (Convert-ToToolPath -WindowsPath $verifyRoot)
    )
    $verifyPairs = @(
        @{ Name = 'system'; Source = $systemImage; Result = (Join-Path $verifyRoot 'system.img') },
        @{ Name = 'vendor'; Source = $vendorImage; Result = (Join-Path $verifyRoot 'vendor.img') },
        @{ Name = 'odm'; Source = $stockOdm; Result = (Join-Path $verifyRoot 'odm.img') }
    )
    $partitionManifest = [ordered]@{}
    foreach ($pair in $verifyPairs) {
        $sourceHash = Get-Sha256 $pair.Source
        $resultHash = Get-Sha256 $pair.Result
        if ($sourceHash -ne $resultHash) {
            throw "Unpacked $($pair.Name) does not match its input image."
        }
        Invoke-Native -FilePath $tools.E2Fsck -ArgumentList @(
            '-fn',
            (Convert-ToToolPath -WindowsPath $pair.Result)
        ) -AllowedExitCodes @(0)
        $partitionManifest[$pair.Name] = [ordered]@{
            Size = (Get-Item -LiteralPath $pair.Result).Length
            Sha256 = $resultHash
        }
    }

    Move-Item -LiteralPath $candidateSuper -Destination $OutputImage
    $outputHash = Get-Sha256 $OutputImage
    $manifest = [ordered]@{
        Tool = 'PLF02WH LineageOS Builder'
        BuiltAtUtc = [DateTime]::UtcNow.ToString('o')
        Device = 'Toss Front 1.5 generation (PLF02WH)'
        Output = [ordered]@{
            FileName = [IO.Path]::GetFileName($OutputImage)
            Size = (Get-Item -LiteralPath $OutputImage).Length
            Sha256 = $outputHash
        }
        Inputs = [ordered]@{
            StockSuper = [ordered]@{ FileName = [IO.Path]::GetFileName($StockSuper); Sha256 = Get-Sha256 $StockSuper }
            Lineage = [ordered]@{ FileName = [IO.Path]::GetFileName($LineageImage); Sha256 = Get-Sha256 $LineageImage }
            OpenGApps = [ordered]@{ FileName = [IO.Path]::GetFileName($OpenGApps); Sha256 = Get-Sha256 $OpenGApps }
        }
        LogicalPartitions = $partitionManifest
        FlashScope = 'super only'
        Notes = @(
            'Do not flash this image on PLF00WH or Toss Front generation 2.',
            'The generated image contains Google proprietary applications and is for personal use only.',
            'Keep original backups private.'
        )
    }
    $manifestPath = "$OutputImage.manifest.json"
    $json = $manifest | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($manifestPath, $json, (New-Object Text.UTF8Encoding($false)))

    $success = $true
    Write-Host ''
    Write-Host 'Build and verification completed.' -ForegroundColor Green
    Write-Host "Image:    $OutputImage"
    Write-Host "SHA-256: $outputHash"
    Write-Host "Manifest: $manifestPath"
} finally {
    $env:PATH = $oldPath
    for ($index = $script:AsciiPathMappings.Count - 1; $index -ge 0; $index--) {
        $mapping = $script:AsciiPathMappings[$index]
        & subst.exe $mapping.Drive /D 2>$null
    }
    if ($success -and -not $KeepWork) {
        $safeBase = [IO.Path]::GetFullPath($workBase).TrimEnd('\') + '\'
        $safeTarget = [IO.Path]::GetFullPath($workRoot)
        if (-not $safeTarget.StartsWith($safeBase, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean an unexpected work path: $safeTarget"
        }
        Remove-Item -LiteralPath $safeTarget -Recurse -Force
    } elseif (-not $success) {
        Write-Warning "Build failed. Diagnostic work directory was kept: $workRoot"
    }
}
