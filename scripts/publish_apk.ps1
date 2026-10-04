<#
.SYNOPSIS
  Build APK release (arm64) roi tai len VPS de tai ve tai
  http://103.82.21.150:9001/posturex-latest.apk

.DESCRIPTION
  Chay tu goc repo:  .\scripts\publish_apk.ps1
  Bo qua build (dung APK da build san):  .\scripts\publish_apk.ps1 -SkipBuild

  Khong can sudo. Tren VPS da co san mot tien trinh
  `python3 -m http.server 9001` (chay tay duoi user hiephann, KHONG phai service)
  phat thu muc /home/hiephann/apk_release o cong 9001 — script chep APK vao dung
  thu muc do. DUNG dung them service thu hai o cong 9001 (se dung cong).
  Ban cu duoc giu lai thanh posturex-prev.apk truoc khi thay.
  Neu tien trinh 9001 chet (VPS khoi dong lai), khoi dong lai bang:
    cd ~/apk_release && nohup python3 -m http.server 9001 --bind 0.0.0.0 > server.log 2>&1 &
  Khoa SSH mac dinh la sshkey.pem o goc repo (da bi .gitignore chan).
#>
param(
  [switch]$SkipBuild,
  [string]$Key = "sshkey.pem",
  [string]$Server = "hiephann@103.82.21.150",
  [string]$RemoteDir = "/home/hiephann/apk_release"
)

# KHONG dung "Stop": Windows PowerShell 5.1 coi moi dong flutter/ssh in ra stderr
# (ke ca canh bao vo hai) la loi va dung script. Thay vao do kiem tra ma thoat
# ($LASTEXITCODE) tung lenh va `throw` tuong minh ben duoi.
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

$apk = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"

if (-not $SkipBuild) {
  flutter build apk --release --split-per-abi
  if ($LASTEXITCODE -ne 0) { throw "flutter build that bai" }
}
if (-not (Test-Path $apk)) { throw "Khong thay $apk - chay lai khong co -SkipBuild" }
if (-not (Test-Path $Key)) { throw "Khong thay khoa SSH '$Key' (dung -Key <duong-dan>)" }

ssh -i $Key $Server "test -d $RemoteDir"
if ($LASTEXITCODE -ne 0) { throw "Khong thay thu muc $RemoteDir tren VPS (hoac SSH that bai)" }

# Chep vao ten tam roi doi ten: nguoi dang tai file khong bao gio nhan ban do dang.
scp -i $Key $apk "${Server}:$RemoteDir/posturex-latest.apk.tmp"
if ($LASTEXITCODE -ne 0) { throw "scp that bai" }
ssh -i $Key $Server "cd $RemoteDir && { [ -f posturex-latest.apk ] && mv -f posturex-latest.apk posturex-prev.apk; mv -f posturex-latest.apk.tmp posturex-latest.apk; } && ls -l --time-style=long-iso *.apk"
if ($LASTEXITCODE -ne 0) { throw "Doi ten tren VPS that bai" }

Write-Host "`nXong: http://103.82.21.150:9001/posturex-latest.apk"
