"""Áp phân loại SpineLoad / Impact / Difficulty cho 417 bài tập qua Admin API.

Chạy một lần sau khi deploy phiên bản có ExerciseUpdate.spine_load / .impact:
    python scripts/bulk_classify_exercises.py [--dry-run] [--base-url URL]

Mặc định gọi VPS production. --dry-run chỉ in ra, không gọi API thực.
"""

import argparse
import json
import os
import sys
import time

import requests

BASE_URL = os.getenv("API_BASE_URL", "http://103.82.21.150:9000")
CLASSIFIED_JSON = os.path.join(os.path.dirname(__file__), "..", "scripts", "exercises_classified.json")

# Thử tìm file ở C:/Temp nếu không có bên cạnh script
_FALLBACK_JSON = "C:/Temp/exercises_classified.json"


def login(base_url: str, email: str, password: str) -> str:
    r = requests.post(
        f"{base_url}/api/v1/auth/login",
        json={"email": email, "password": password},
        timeout=15,
    )
    r.raise_for_status()
    return r.json()["access_token"]


def patch_exercise(base_url: str, token: str, exercise_id: int, payload: dict) -> bool:
    r = requests.patch(
        f"{base_url}/api/v1/admin/exercises/{exercise_id}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    if r.status_code == 200:
        return True
    print(f"  [!] id={exercise_id} -> HTTP {r.status_code}: {r.text[:120]}")
    return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Bulk-classify exercises via Admin API")
    parser.add_argument("--dry-run", action="store_true", help="In ra thay vì gọi API")
    parser.add_argument("--base-url", default=BASE_URL, help="URL gốc của backend")
    parser.add_argument("--email", default="", help="Email tài khoản admin")
    parser.add_argument("--password", default="", help="Mật khẩu admin")
    args = parser.parse_args()

    # Tìm file phân loại
    json_path = CLASSIFIED_JSON if os.path.exists(CLASSIFIED_JSON) else _FALLBACK_JSON
    if not os.path.exists(json_path):
        sys.exit("exercises_classified.json not found. Run classify_exercises.py first.")

    with open(json_path, encoding="utf-8") as f:
        exercises = json.load(f)

    print(f"Loaded {len(exercises)} exercises from {json_path}")
    print(f"Base URL: {args.base_url}")

    if args.dry_run:
        print("\n[DRY RUN] First 5 exercises:")
        for ex in exercises[:5]:
            spine = ex["spine"] if ex["spine"] != "None" else None
            print(f"  PATCH /admin/exercises/{ex['id']}  {ex['name']!r}")
            print(f"    difficulty={ex['difficulty']!r}  spine_load={spine!r}  impact={ex['impact']!r}")
        print(f"\n... and {len(exercises) - 5} more")
        return

    email = args.email or input("Admin email: ").strip()
    password = args.password or input("Admin password: ").strip()

    print("\nLogging in...")
    try:
        token = login(args.base_url, email, password)
    except Exception as e:
        sys.exit(f"Login failed: {e}")
    print("Login OK.\n")

    ok = 0
    fail = 0
    for i, ex in enumerate(exercises, 1):
        spine = ex["spine"] if ex["spine"] != "None" else None
        payload = {
            "difficulty": ex["difficulty"],
            "spine_load": spine,
            "impact": ex["impact"],
        }
        success = patch_exercise(args.base_url, token, ex["id"], payload)
        if success:
            ok += 1
        else:
            fail += 1
        if i % 50 == 0:
            print(f"  [{i}/{len(exercises)}] ok={ok} fail={fail}")
        time.sleep(0.05)

    print(f"\nDone: {ok} OK, {fail} failed / {len(exercises)} total.")


if __name__ == "__main__":
    main()
