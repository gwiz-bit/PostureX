"""Sao lưu database ra file .sql.gz, giữ N bản gần nhất.

Vì sao cần dù VPS đã bật auto-backup của Cloudfly: snapshot là ảnh chụp CẢ
máy. Khôi phục snapshot nghĩa là quay ngược mọi thứ — code mới, log, cấu hình
— về đúng thời điểm đó. Còn khi chỉ hỏng dữ liệu (xoá nhầm bảng, chạy nhầm
`create_tables.py` vốn DROP + tạo lại videos/workouts), thứ bạn cần là lấy
lại đúng phần dữ liệu mà không đụng gì khác. Chỉ dump DB mới làm được.

Mật khẩu KHÔNG truyền qua tham số dòng lệnh: `--password=...` hiện nguyên
văn trong `ps aux` cho mọi user trên máy. Script ghi tạm một file cấu hình
chmod 600 rồi đưa cho mysqldump qua `--defaults-extra-file`, xoá ngay sau khi
xong.

Cách dùng (trên server, trong thư mục backend/):

    venv/bin/python scripts/backup_db.py                    # mac dinh: /opt/posturex/backups, giu 7 ban
    venv/bin/python scripts/backup_db.py --keep 14
    venv/bin/python scripts/backup_db.py --dest /mnt/backup

Chạy tự động hằng ngày lúc 3h sáng — thêm vào crontab của root:

    0 3 * * * cd /opt/posturex/backend && venv/bin/python scripts/backup_db.py \
        >> /var/log/posturex-backup.log 2>&1
"""

import argparse
import gzip
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings

DEFAULT_DEST = "/opt/posturex/backups"
FILE_PREFIX = "posturex-"
FILE_SUFFIX = ".sql.gz"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sao luu database ra file .sql.gz, giu N ban gan nhat."
    )
    parser.add_argument("--dest", default=DEFAULT_DEST, help=f"Thu muc luu (mac dinh: {DEFAULT_DEST}).")
    parser.add_argument("--keep", type=int, default=7, help="Giu bao nhieu ban gan nhat (mac dinh: 7).")
    return parser.parse_args()


def write_defaults_file(directory: str) -> str:
    """Ghi file cấu hình tạm chứa mật khẩu, chỉ chủ sở hữu đọc được."""
    path = os.path.join(directory, "my.cnf")
    with open(path, "w", encoding="utf-8") as f:
        f.write(
            "[client]\n"
            f"user={settings.DB_USER}\n"
            f"password={settings.DB_PASSWORD}\n"
            f"host={settings.DB_HOST}\n"
            f"port={settings.DB_PORT}\n"
        )
    os.chmod(path, 0o600)
    return path


def prune(dest: Path, keep: int) -> list[Path]:
    """Xoá bản cũ, giữ `keep` bản mới nhất. Trả danh sách file đã xoá."""
    backups = sorted(
        dest.glob(f"{FILE_PREFIX}*{FILE_SUFFIX}"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    removed = []
    for old in backups[keep:]:
        old.unlink()
        removed.append(old)
    return removed


def main() -> None:
    args = parse_args()

    if shutil.which("mysqldump") is None:
        print("Khong tim thay lenh 'mysqldump' trong PATH.", file=sys.stderr)
        sys.exit(1)

    dest = Path(args.dest)
    dest.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_path = dest / f"{FILE_PREFIX}{stamp}{FILE_SUFFIX}"

    with tempfile.TemporaryDirectory() as tmp:
        defaults_file = write_defaults_file(tmp)
        command = [
            "mysqldump",
            f"--defaults-extra-file={defaults_file}",
            # Dump nhat quan ma khong khoa bang — InnoDB doc snapshot trong
            # mot transaction, nen backend van ghi binh thuong luc dang dump.
            "--single-transaction",
            "--routines",
            "--triggers",
            settings.DB_NAME,
        ]

        # Ghi ra file tam truoc roi moi doi ten: neu mysqldump chet giua chung,
        # thu muc backup khong bi bo lai mot file .sql.gz cut ma nhin vao lai
        # tuong la ban sao luu hop le.
        partial = out_path.with_suffix(out_path.suffix + ".partial")
        try:
            with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
                with gzip.open(partial, "wb") as gz:
                    shutil.copyfileobj(proc.stdout, gz)
                stderr = proc.stderr.read().decode("utf-8", errors="replace")
            if proc.returncode != 0:
                partial.unlink(missing_ok=True)
                print(f"mysqldump that bai (ma loi {proc.returncode}):\n{stderr}", file=sys.stderr)
                sys.exit(1)
        except Exception:
            partial.unlink(missing_ok=True)
            raise

        partial.rename(out_path)

    size_mb = out_path.stat().st_size / 1048576
    print(f"{datetime.now():%Y-%m-%d %H:%M:%S} | da tao {out_path} ({size_mb:.2f} MB)")

    removed = prune(dest, args.keep)
    for old in removed:
        print(f"  - xoa ban cu: {old.name}")
    print(f"  giu lai {args.keep} ban gan nhat")


if __name__ == "__main__":
    main()
