"""Chạy sql/postureX123_schema.sql len MySQL. Doc config tu .env (app.core.config).

Cach dung:
    venv\\Scripts\\python.exe sql\\run_schema.py
"""

import asyncio
import re
import sys
from pathlib import Path

import aiomysql

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402

SCHEMA_FILE = Path(__file__).parent / "postureX123_schema.sql"


def split_statements(sql: str) -> list[str]:
    """Tach script thanh danh sach statement, xu ly rieng khoi
    DELIMITER $$ ... END$$ DELIMITER ; cua stored procedure (DELIMITER
    chi la quy uoc cua mysql CLI, khong can khi gui truc tiep qua driver).
    """
    statements: list[str] = []

    delim_start = sql.index("DELIMITER $$")
    delim_end = sql.index("DELIMITER ;", delim_start)

    before = sql[:delim_start]
    proc_block = sql[delim_start + len("DELIMITER $$") : delim_end]
    after = sql[delim_end + len("DELIMITER ;") :]

    statements.extend(_split_simple(before))

    proc_block = proc_block.strip()
    if proc_block.endswith("$$"):
        proc_block = proc_block[: -len("$$")].strip()
    if proc_block:
        statements.append(proc_block)

    statements.extend(_split_simple(after))

    return [s for s in statements if s.strip()]


def _split_simple(sql: str) -> list[str]:
    # Bo comment block /* ... */ va comment dong -- ... truoc khi tach theo ';'
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    sql = re.sub(r"--.*", "", sql)
    return [s.strip() for s in sql.split(";") if s.strip()]


async def main() -> None:
    sql = SCHEMA_FILE.read_text(encoding="utf-8")
    statements = split_statements(sql)
    print(f"Se chay {len(statements)} statement tu {SCHEMA_FILE.name}")

    conn = await aiomysql.connect(
        host=settings.DB_HOST,
        port=settings.DB_PORT,
        user=settings.DB_USER,
        password=settings.DB_PASSWORD,
        autocommit=True,
    )
    cur = await conn.cursor()

    for i, stmt in enumerate(statements, 1):
        preview = " ".join(stmt.split())[:80]
        try:
            await cur.execute(stmt)
            if cur.description:
                rows = await cur.fetchall()
                for row in rows:
                    print(" ", row)
        except Exception as e:
            print(f"[{i}/{len(statements)}] LOI khi chay: {preview}...")
            print("   ", e)
            raise
        else:
            print(f"[{i}/{len(statements)}] OK: {preview}")

    await cur.close()
    conn.close()
    print("Hoan tat.")


asyncio.run(main())
