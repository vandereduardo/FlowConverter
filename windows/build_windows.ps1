$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$outDir = Join-Path $scriptDir "build\FlowConverter"

$dotnetExe = "dotnet"
if (-not (Get-Command $dotnetExe -ErrorAction SilentlyContinue)) {
    $localDotnet = "$env:LOCALAPPDATA\Programs\dotnet\dotnet.exe"
    if (Test-Path $localDotnet) {
        $dotnetExe = $localDotnet
        $env:DOTNET_ROOT = "$env:LOCALAPPDATA\Programs\dotnet"
    } else {
        throw ".NET 8 SDK (dotnet.exe) not found. Please install .NET 8 SDK."
    }
}

Write-Host "==> Building FlowConverter for Windows (.NET 8 / WPF)..." -ForegroundColor Cyan
& $dotnetExe publish (Join-Path $scriptDir "src\FlowConverter.Windows\FlowConverter.Windows.csproj") `
    -c Release `
    -o $outDir `
    --nologo

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

$resDir = Join-Path $outDir "Resources"
$scriptsDir = Join-Path $resDir "Scripts"
New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null

$macWav = Join-Path $repoRoot "macos\Resources\HighlightSound.wav"
if (Test-Path $macWav) {
    Copy-Item $macWav (Join-Path $resDir "HighlightSound.wav") -Force
}

$officePy = Join-Path $repoRoot "macos\Resources\Scripts\flow_office_converter.py"
if (Test-Path $officePy) {
    Copy-Item $officePy (Join-Path $scriptsDir "flow_office_converter.py") -Force
}

$anycubicProfiles = "C:\Program Files\AnycubicSlicerNext\resources\profiles"
if (Test-Path $anycubicProfiles) {
    Write-Host "==> Bundling official Anycubic 3D printer profiles..." -ForegroundColor Cyan
    $targetProfiles = Join-Path $resDir "profiles"
    New-Item -ItemType Directory -Force -Path $targetProfiles | Out-Null
    $anycubicJson = Join-Path $anycubicProfiles "Anycubic.json"
    $anycubicFolder = Join-Path $anycubicProfiles "Anycubic"
    if (Test-Path $anycubicJson) {
        Copy-Item $anycubicJson (Join-Path $targetProfiles "Anycubic.json") -Force
    }
    if (Test-Path $anycubicFolder) {
        Copy-Item $anycubicFolder (Join-Path $targetProfiles "Anycubic") -Recurse -Force
    }
}

Write-Host "==> Build complete! Output: $outDir\FlowConverter.exe" -ForegroundColor Green
