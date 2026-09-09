[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Set-Location -LiteralPath $PSScriptRoot

    Write-Host 'super.img 이미지 파일을 이 창으로 끌어다 놓고 Enter 키를 누르세요.'
    $sourceInput = Read-Host '파일'
    if ([string]::IsNullOrWhiteSpace($sourceInput)) {
        throw '파일을 입력하지 않았습니다.'
    }

    $sourceInput = $sourceInput.Trim().Trim('"')
    if (-not (Test-Path -LiteralPath $sourceInput -PathType Leaf)) {
        throw "입력한 파일을 찾을 수 없습니다: $sourceInput"
    }

    $sourcePath = (Resolve-Path -LiteralPath $sourceInput).Path
    $inputDirectory = Join-Path $PSScriptRoot 'input'
    $destinationPath = Join-Path $inputDirectory 'stock-super.img'
    New-Item -ItemType Directory -Force -Path $inputDirectory | Out-Null

    if (-not $sourcePath.Equals($destinationPath, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host '이미지를 복사하고 있습니다...'
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }

    Write-Host '빌드를 시작합니다...'
    & (Join-Path $PSScriptRoot 'Build-PLF02WH.ps1') -DownloadInputs -AcceptOpenGAppsPersonalUse

    Write-Host ''
    Write-Host '빌드가 완료되었습니다.' -ForegroundColor Green
    Write-Host '결과 파일: output\super_PLF02WH_lineage18.1_gapps_pico.img'
    exit 0
} catch {
    Write-Host ''
    Write-Host '빌드에 실패했습니다.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
