"""Dong bo cot SupportsAnalysis trong bang Exercises tu ANALYZER_REGISTRY.

Chay mot lan sau moi lan deploy them analyzer moi:
    python scripts/sync_supports_analysis.py [--dry-run]

SupportsAnalysis = 1  neu exercise.name.lower() co trong ANALYZER_REGISTRY
SupportsAnalysis = 0  neu khong co (hop le -- chi la chua ho tro phan tich)

Khac voi bulk_classify_exercises.py (goi Admin API), script nay ket noi TRUC
TIEP vao MySQL qua .env -- phai chay TREN SERVER hoac tu may dev co MySQL ket
noi duoc.
"""

import argparse
import asyncio

from sqlalchemy import select, update

from app.core.database import AsyncSessionLocal
from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.models.exercise import Exercise


async def sync(dry_run: bool = False) -> None:
    supported = {name.lower() for name in ANALYZER_REGISTRY}

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Exercise))
        exercises = result.scalars().all()

        to_on: list[int] = []
        to_off: list[int] = []

        for ex in exercises:
            want = 1 if ex.name.lower() in supported else 0
            have = ex.supports_analysis
            if want != have:
                if want:
                    to_on.append(ex.id)
                else:
                    to_off.append(ex.id)

    print(f"Total exercises:  {len(exercises)}")
    print(f"In registry:      {len(to_on) + sum(1 for e in exercises if e.name.lower() in supported)}")
    print(f"Will set ON  (+): {len(to_on)}")
    print(f"Will set OFF (-): {len(to_off)}")

    if not to_on and not to_off:
        print("Already in sync -- nothing to do.")
        return

    if dry_run:
        if to_on:
            print("\nWould set SupportsAnalysis=1:")
            for eid in sorted(to_on):
                print(f"  id={eid}")
        if to_off:
            print("\nWould set SupportsAnalysis=0:")
            for eid in sorted(to_off):
                print(f"  id={eid}")
        return

    async with AsyncSessionLocal() as db, db.begin():
        if to_on:
            await db.execute(
                update(Exercise)
                .where(Exercise.id.in_(to_on))
                .values(supports_analysis=1)
            )
        if to_off:
            await db.execute(
                update(Exercise)
                .where(Exercise.id.in_(to_off))
                .values(supports_analysis=0)
            )

    print(f"Done: {len(to_on)} set ON, {len(to_off)} set OFF.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync SupportsAnalysis from ANALYZER_REGISTRY")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    asyncio.run(sync(dry_run=args.dry_run))


if __name__ == "__main__":
    main()
