$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$iconDir = Join-Path $root 'assets\icon'
$iconPath = Join-Path $iconDir 'deir_al_balah_municipality.png'

New-Item -ItemType Directory -Force -Path $iconDir | Out-Null

$logoUrl = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/6/62/Seal_of_Deir_al-Balah.tif/lossless-page1-500px-Seal_of_Deir_al-Balah.tif.png'

Write-Host 'Downloading the official Deir al-Balah Municipality seal...' -ForegroundColor Cyan
Invoke-WebRequest -Uri $logoUrl -OutFile $iconPath

if (!(Test-Path $iconPath) -or ((Get-Item $iconPath).Length -lt 1000)) {
    throw 'Municipality logo download failed or produced an invalid file.'
}

Write-Host "Logo saved to: $iconPath" -ForegroundColor Green
Write-Host 'Now run: flutter pub get' -ForegroundColor Yellow
Write-Host 'Then run: dart run flutter_launcher_icons' -ForegroundColor Yellow
