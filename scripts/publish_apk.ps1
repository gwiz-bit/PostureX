<#
.SYNOPSIS
  Build APK release (arm64) roi tai len VPS de tai ve tai
  http://103.82.21.150:9001/posturex-latest.apk

.DESCRIPTION
  Chay tu goc repo:  .\scripts\publish_apk.ps1
  Bo qua build (dung APK da build san):  .\scripts\publish_apk.ps1 -SkipBuild

  Khong can sudo: APK duoc chep vao ~/apk cua user hiephann tren VPS, con service
  `posturex-apk.service` (python3 -m http.server 9001 --directory /home/hiephann/apk,
  chay duoi user hiephann, cai MOT LAN bang sudo) phat thu muc do o cong 9001.
  Khoa SSH mac dinh la sshkey.pem o goc repo (da bi .gitignore chan).
#>
param(
  [switch]$SkipBuild,
  [string]$Key = "sshkey.pem",
  [string]$Server = "hiephann@103.82.21.150"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$apk = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"

if (-not $SkipBuild) {
  flutter build apk --release --split-per-abi
  if ($LASTEXITCODE -ne 0) { throw "flutter build that bai" }
}
if (-not (Test-Path $apk)) { throw "Khong thay $apk - chay lai khong co -SkipBuild" }
if (-not (Test-Path $Key)) { throw "Khong thay khoa SSH '$Key' (dung -Key <duong-dan>)" }

ssh -i $Key $Server "mkdir -p ~/apk"
if ($LASTEXITCODE -ne 0) { throw "SSH that bai" }

# Chep vao ten tam roi doi ten: nguoi dang tai file khong bao gio nhan ban do dang.
scp -i $Key $apk "${Server}:~/apk/posturex-latest.apk.tmp"
if ($LASTEXITCODE -ne 0) { throw "scp that bai" }
ssh -i $Key $Server "mv -f ~/apk/posturex-latest.apk.tmp ~/apk/posturex-latest.apk && ls -l ~/apk"

Write-Host "`nXong: http://103.82.21.150:9001/posturex-latest.apk"
