"""Nạp thư viện video bài tập vào DB và đưa file về đúng chỗ backend phục vụ.

Bối cảnh: 412 video demo được upload thủ công lên server vào
`backend/video/<Nhóm cơ>/<ten-bai>.mp4`. App KHÔNG quét thư mục — nó đọc
đường dẫn từ cột `Exercises.DemoVideoUrl`, nên chừng nào chưa có script này
thì 890 MB video kia không có đường nào ra tới người dùng.

Script làm ba việc, chạy lại nhiều lần vẫn an toàn (idempotent):

1. Chuyển file sang `storage/exercise_videos/` dạng PHẲNG. Bắt buộc phẳng vì
   endpoint phục vụ video khai báo `/media/exercise-videos/{filename}` — mà
   `{filename}` trong FastAPI không khớp dấu `/`, nên `Back/pull-up.mp4` sẽ
   404. Mặc định là `move` chứ không `copy`: đĩa server chỉ còn ~12 GB, copy
   là chiếm thêm 890 MB vô ích.
2. Thêm nhóm cơ còn thiếu vào bảng `MuscleGroups` (schema mới seed 10, thư
   mục video có 16).
3. Với mỗi video: tạo/cập nhật một dòng `Exercises` trỏ `DemoVideoUrl` vào
   file, cộng một dòng `ExerciseMuscleGroups` gắn bài với nhóm cơ của thư mục
   (đặt `IsPrimary=1` — thư mục chính là cách nguồn video phân loại bài).

Về metadata: chỉ điền những gì THẬT SỰ suy được từ nguồn — tên bài (từ tên
file) và nhóm cơ (từ thư mục). `Description`, `Category`, `Difficulty`, `Met`
để NULL, KHÔNG bịa giá trị mặc định:

- `Difficulty='Beginner'` cho cả 412 bài là sai dữ liệu — muscle-up hay
  pistol squat rõ ràng không phải Beginner, mà app lại hiện chip độ khó ở cả
  màn danh sách lẫn màn chi tiết. Để NULL thì client bỏ qua chip đó
  (`if (exercise.difficulty != null)`), thà không hiện còn hơn hiện sai.
- `Met` (chỉ số ước tính calo) hiện KHÔNG có dòng code nào đọc — cả backend
  lẫn Flutter đều chỉ lưu và trả về. Bịa 4.0 chỉ tạo ảo giác là có dữ liệu.
- `Category` suy từ tên file không đáng tin: chỉ ~42/412 file có từ khoá gợi
  ý, và khớp chuỗi thì dương tính giả nhiều (`*run*` trúng cả
  "trunk-rotation", `*cycl*` trúng "bicycle-crunch" vốn là Core).

Cách dùng (chạy trên server, trong thư mục backend/):

    venv/bin/python scripts/import_exercise_videos.py --dry-run   # xem trước
    venv/bin/python scripts/import_exercise_videos.py             # chạy thật
"""

import argparse
import asyncio
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select

from app.core.config import settings
from app.core.database import AsyncSessionLocal, engine
from app.models.exercise import Exercise
from app.models.muscle_group import ExerciseMuscleGroup, MuscleGroup
from app.services.exercise_video_service import PUBLIC_URL_PREFIX

VIDEO_EXTENSION = ".mp4"


def exercise_name_from_filename(filename: str) -> str:
    """`band-assisted-pull-up.mp4` -> `Band Assisted Pull Up`.

    Nhận cả gạch dưới lẫn gạch ngang để không phụ thuộc nguồn video đặt tên
    theo kiểu nào. Cột `Exercises.Name` là VARCHAR(100) nên cắt cho vừa.
    """
    stem = Path(filename).stem.replace("_", " ").replace("-", " ")
    return " ".join(word.capitalize() for word in stem.split())[:100]


def scan_source(source_dir: Path) -> list[tuple[str, Path]]:
    """Duyệt `source_dir/<Nhóm cơ>/*.mp4`, trả [(tên nhóm cơ, đường dẫn file)].

    Chỉ nhận thư mục con một cấp — đúng cấu trúc nguồn video hiện có. File
    nằm thẳng ở gốc bị bỏ qua vì không biết gán vào nhóm cơ nào.
    """
    found: list[tuple[str, Path]] = []
    for group_dir in sorted(p for p in source_dir.iterdir() if p.is_dir()):
        for video in sorted(group_dir.glob(f"*{VIDEO_EXTENSION}")):
            found.append((group_dir.name, video))
    return found


async def ensure_muscle_groups(session, names: set[str]) -> dict[str, int]:
    """Đảm bảo mọi nhóm cơ trong `names` có mặt, trả map {tên -> id}."""
    result = await session.execute(select(MuscleGroup))
    by_name = {mg.name: mg for mg in result.scalars().all()}

    for name in sorted(names):
        if name not in by_name:
            group = MuscleGroup(name=name)
            session.add(group)
            by_name[name] = group
            print(f"  + nhom co moi: {name}")

    await session.flush()
    return {name: group.id for name, group in by_name.items()}


def parse_args() -> argparse.Namespace:
    """Parse ngoài coroutine: `--help` và tham số sai gọi `sys.exit()`, mà
    SystemExit ném từ trong `asyncio.run()` thì in ra nguyên cục traceback
    thay vì thông báo gọn của argparse."""
    # Mo ta thuan ASCII, KHONG dung __doc__: docstring co dau tieng Viet, ma
    # console Windows mac dinh cp1252 nen `--help` se chet vi UnicodeEncodeError
    # truoc khi in duoc gi. Doc chi tiet thi doc thang docstring dau file.
    parser = argparse.ArgumentParser(
        description="Nap thu vien video bai tap vao DB va dua file ve storage/exercise_videos/."
    )
    parser.add_argument(
        "--source",
        default="video",
        help="Thu muc nguon chua cac thu muc nhom co (mac dinh: video).",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy thay vi move. Mac dinh move de khong ton them dung luong dia.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Chi in ra se lam gi, khong doi file va khong ghi DB.",
    )
    return parser.parse_args()


async def main(args: argparse.Namespace) -> None:
    source_dir = Path(args.source).resolve()
    dest_dir = settings.get_exercise_video_storage_path().resolve()

    if not source_dir.is_dir():
        print(f"Khong tim thay thu muc nguon: {source_dir}")
        sys.exit(1)

    entries = scan_source(source_dir)
    if not entries:
        print(f"Khong co file {VIDEO_EXTENSION} nao trong {source_dir}/<nhom co>/")
        sys.exit(1)

    # Trung ten file giua cac thu muc se de len nhau khi lam phang, va cung se
    # dung ca rang buoc UNIQUE(Name). Chan truoc, dung nua chung moi phat hien.
    names_seen: dict[str, Path] = {}
    clashes: list[tuple[Path, Path]] = []
    for _group, path in entries:
        if path.name in names_seen:
            clashes.append((names_seen[path.name], path))
        names_seen[path.name] = path
    if clashes:
        print(f"DUNG: {len(clashes)} file trung ten, lam phang se de len nhau:")
        for first, second in clashes[:10]:
            print(f"  {first}  <->  {second}")
        sys.exit(1)

    print(f"Nguon : {source_dir}  ({len(entries)} video)")
    print(f"Dich  : {dest_dir}")
    print(f"Che do: {'DRY-RUN (khong thay doi gi)' if args.dry_run else 'THUC THI'}")
    print()

    if args.dry_run:
        groups = sorted({g for g, _ in entries})
        print(f"Nhom co ({len(groups)}): {', '.join(groups)}")
        print("Vi du 5 bai se tao:")
        for group, path in entries[:5]:
            print(f"  {exercise_name_from_filename(path.name)!r}  [{group}]  <- {path.name}")
        await engine.dispose()
        return

    dest_dir.mkdir(parents=True, exist_ok=True)

    moved = skipped_file = created = updated = linked = 0

    async with AsyncSessionLocal() as session:
        group_ids = await ensure_muscle_groups(session, {g for g, _ in entries})

        result = await session.execute(select(Exercise))
        exercises_by_name = {e.name: e for e in result.scalars().all()}

        result = await session.execute(select(ExerciseMuscleGroup))
        existing_links = {(link.exercise_id, link.muscle_group_id) for link in result.scalars().all()}

        for group_name, src_path in entries:
            dest_path = dest_dir / src_path.name

            if dest_path.exists():
                skipped_file += 1
            elif src_path.exists():
                if args.copy:
                    shutil.copy2(src_path, dest_path)
                else:
                    shutil.move(str(src_path), str(dest_path))
                moved += 1

            name = exercise_name_from_filename(src_path.name)
            url = f"{PUBLIC_URL_PREFIX}/{src_path.name}"

            exercise = exercises_by_name.get(name)
            if exercise is None:
                # Chi dien nhung gi suy duoc that su tu nguon — xem docstring.
                exercise = Exercise(
                    name=name,
                    description=None,
                    category=None,
                    difficulty=None,
                    exercise_type="Standard",
                    demo_video_url=url,
                    thumbnail_url=None,
                    met=None,
                    is_active=True,
                )
                session.add(exercise)
                exercises_by_name[name] = exercise
                created += 1
            elif exercise.demo_video_url != url:
                # Bai da co san (vd 6 bai seed goc) — chi gan video, giu nguyen
                # mo ta/do kho ma nguoi khac da dien.
                exercise.demo_video_url = url
                updated += 1

            await session.flush()

            link_key = (exercise.id, group_ids[group_name])
            if link_key not in existing_links:
                session.add(
                    ExerciseMuscleGroup(
                        exercise_id=exercise.id,
                        muscle_group_id=group_ids[group_name],
                        is_primary=True,
                    )
                )
                existing_links.add(link_key)
                linked += 1

        await session.commit()

    print()
    print(f"File chuyen sang {dest_dir.name}/ : {moved}")
    print(f"File da nam san o dich (bo qua) : {skipped_file}")
    print(f"Bai tap tao moi                 : {created}")
    print(f"Bai tap cap nhat video          : {updated}")
    print(f"Lien ket bai <-> nhom co        : {linked}")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main(parse_args()))
