# Chay backend PostureX bang 1 lenh, tu lo lieu setup lan dau tren may moi
# clone (venv, dependencies, .env, model MediaPipe, database), sau do khoi
# dong uvicorn. Chay lai nhieu lan deu an toan — khong xoa du lieu da co.
#
# Cach dung (tu thu muc lib/backend):
#   .\run.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# 1. venv
if (-not (Test-Path "venv")) {
    Write-Host "Tao virtualenv..."
    python -m venv venv
}

# 2. Dependencies
Write-Host "Cai dependencies (bo qua neu da du)..."
& venv\Scripts\pip.exe install -q -r requirements.txt

# 3. .env — khong the tu doan mat khau MySQL/SMTP cua ban, phai dien tay
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ""
    Write-Host "Da tao lib/backend/.env tu .env.example." -ForegroundColor Yellow
    Write-Host "Mo file .env len va dien it nhat DB_PASSWORD (mat khau MySQL cua ban)," -ForegroundColor Yellow
    Write-Host "roi chay lai '.\run.ps1'." -ForegroundColor Yellow
    exit 1
}

# 4. Model MediaPipe (download_models.py tu bo qua neu da co san)
& venv\Scripts\python.exe download_models.py

# 5. Database — lan dau (database rong) thi tao schema + bang + admin mau,
#    tu lan sau chi dong bo bang con thieu, khong dong gi du lieu da co.
$hasUsers = (& venv\Scripts\python.exe -c @"
import asyncio
from sqlalchemy import inspect
from app.core.database import engine

async def check() -> bool:
    async with engine.connect() as conn:
        return await conn.run_sync(lambda sync_conn: inspect(sync_conn).has_table('Users'))

print(asyncio.run(check()))
"@).Trim()

if ($hasUsers -ne "True") {
    Write-Host "Database rong -- khoi tao schema + tai khoan admin mau..."
    & venv\Scripts\python.exe sql\run_schema.py
    & venv\Scripts\python.exe create_tables.py
    & venv\Scripts\python.exe create_admin.py admin@posturex.com Admin123 "Super Admin"
    Write-Host "Da tao admin: admin@posturex.com / Admin123"
} else {
    Write-Host "Database da co du lieu -- chi dong bo bang con thieu..."
    & venv\Scripts\python.exe ensure_tables.py
}

# 6. Chay server
Write-Host ""
Write-Host "Backend chay tai http://localhost:9000 (Ctrl+C de dung)" -ForegroundColor Green
& venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 9000
