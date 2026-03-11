"""Import district boundaries GeoJSON into Supabase table: district_boundaries.

Usage:
  python backend_fastapi/scripts/import_district_boundaries.py
  python backend_fastapi/scripts/import_district_boundaries.py --geojson malaysia.district.geojson
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from app.db.supabase_client import get_client


DEFAULT_GEOJSON = Path(__file__).resolve().parents[2] / "malaysia.district.geojson"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import district boundaries into Supabase")
    parser.add_argument(
        "--geojson",
        type=Path,
        default=DEFAULT_GEOJSON,
        help="Path to malaysia district GeoJSON file",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    path = args.geojson.resolve()

    if not path.exists():
        raise FileNotFoundError(f"GeoJSON not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    features = data.get("features", [])
    if not features:
        raise ValueError("No features found in GeoJSON")

    rows = []
    for feature in features:
        props = feature.get("properties", {})
        geometry = feature.get("geometry")
        if not geometry:
            continue

        row = {
            "id": str(feature.get("id") or props.get("name", "")).strip().lower().replace(" ", "-"),
            "name": str(props.get("name", "")).strip(),
            "state": str(props.get("state", "")).strip(),
            "code_state": props.get("code_state"),
            "geometry": geometry,
            "active": True,
        }

        if not row["id"] or not row["name"]:
            continue

        rows.append(row)

    if not rows:
        raise ValueError("No valid boundary rows to import")

    sb = get_client()

    chunk_size = 200
    inserted = 0
    for i in range(0, len(rows), chunk_size):
        chunk = rows[i : i + chunk_size]
        sb.table("district_boundaries").upsert(chunk, on_conflict="id").execute()
        inserted += len(chunk)

    print(f"Imported/updated {inserted} district boundaries from {path}")


if __name__ == "__main__":
    main()
