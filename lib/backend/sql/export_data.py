"""Xuat toan bo database hien tai ra sql/data_dump.sql.

File nay nam trong .gitignore — KHONG tu dong len git khi push code.
Chua du lieu that (email, mat khau da hash cua user), nen chi gui thu
cong cho dong doi qua kenh rieng tu (chat, drive rieng...), tuyet doi
khong commit/push len git du repo public hay private.

Cach dung:
    venv\\Scripts\\python.exe sql\\export_data.py
"""

import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402

OUTPUT_FILE = Path(__file__).parent / "data_dump.sql"

# Cac vi tri pho bien cua mysqldump.exe tren Windows neu khong co san
# trong PATH — them vao day neu may ban cai o cho khac.
_FALLBACK_PATHS = [
    r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqldump.exe",
    r"C:\Program Files\MySQL\MySQL Server 9.3\bin\mysqldump.exe",
    r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe",
    r"C:\xampp\mysql\bin\mysqldump.exe",
]


def find_mysqldump() -> str:
    found = shutil.which("mysqldump") or shutil.which("mysqldump.exe")
    if found:
        return found
    for path in _FALLBACK_PATHS:
        if Path(path).exists():
            return path
    print("Khong tim thay mysqldump.exe. Them duong dan vao _FALLBACK_PATHS")
    print("trong file nay, hoac them thu muc bin cua MySQL vao PATH.")
    sys.exit(1)


def main() -> None:
    mysqldump = find_mysqldump()
    print(f"Dung mysqldump: {mysqldump}")
    print(f"Xuat database '{settings.DB_NAME}' ra {OUTPUT_FILE}...")

    with OUTPUT_FILE.open("w", encoding="utf-8") as f:
        result = subprocess.run(
            [
                mysqldump,
                "-h", settings.DB_HOST,
                "-P", str(settings.DB_PORT),
                "-u", settings.DB_USER,
                f"-p{settings.DB_PASSWORD}",
                "--routines",
                "--triggers",
                "--single-transaction",
                settings.DB_NAME,
            ],
            stdout=f,
            stderr=subprocess.PIPE,
            text=True,
        )

    if result.returncode != 0:
        print("Loi khi xuat database:")
        print(result.stderr)
        sys.exit(1)

    print(f"Xong! Da ghi vao {OUTPUT_FILE} ({OUTPUT_FILE.stat().st_size} bytes)")
    print("File nay bi gitignore — tu gui thu cong cho dong doi, khong push len git.")


if __name__ == "__main__":
    main()
