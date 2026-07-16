"""Nap sql/data_dump.sql vao database — dung sau khi nhan file nay tu
dong doi (qua kenh rieng tu, KHONG qua git — xem export_data.py) de co
du lieu moi nhat cua team (thay the cho run_schema.py + create_tables.py +
create_admin.py, vi data_dump.sql da co san schema + du lieu day du).

CANH BAO: se DROP va tao lai database (data_dump.sql bat dau bang
`DROP DATABASE IF EXISTS` + `CREATE DATABASE`) — chi chay khi khong con
du lieu quan trong nao khac trong database dich.

Cach dung:
    venv\\Scripts\\python.exe sql\\import_data.py
"""

import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402

DUMP_FILE = Path(__file__).parent / "data_dump.sql"

_FALLBACK_PATHS = [
    r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe",
    r"C:\Program Files\MySQL\MySQL Server 9.3\bin\mysql.exe",
    r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
    r"C:\xampp\mysql\bin\mysql.exe",
]


def find_mysql_cli() -> str:
    found = shutil.which("mysql") or shutil.which("mysql.exe")
    if found:
        return found
    for path in _FALLBACK_PATHS:
        if Path(path).exists():
            return path
    print("Khong tim thay mysql.exe. Them duong dan vao _FALLBACK_PATHS")
    print("trong file nay, hoac them thu muc bin cua MySQL vao PATH.")
    sys.exit(1)


def main() -> None:
    if not DUMP_FILE.exists():
        print(f"Khong tim thay {DUMP_FILE} — chay export_data.py ben phia")
        print("nguoi giu du lieu goc truoc, roi pull/copy file nay ve.")
        sys.exit(1)

    mysql_cli = find_mysql_cli()
    print(f"Dung mysql: {mysql_cli}")
    print(f"Nap {DUMP_FILE} vao MySQL ({settings.DB_HOST}:{settings.DB_PORT})...")

    with DUMP_FILE.open("r", encoding="utf-8") as f:
        result = subprocess.run(
            [
                mysql_cli,
                "-h", settings.DB_HOST,
                "-P", str(settings.DB_PORT),
                "-u", settings.DB_USER,
                f"-p{settings.DB_PASSWORD}",
            ],
            stdin=f,
            stderr=subprocess.PIPE,
            text=True,
        )

    if result.returncode != 0:
        print("Loi khi nap du lieu:")
        print(result.stderr)
        sys.exit(1)

    print("Xong! Database da duoc nap day du du lieu tu data_dump.sql.")


if __name__ == "__main__":
    main()
