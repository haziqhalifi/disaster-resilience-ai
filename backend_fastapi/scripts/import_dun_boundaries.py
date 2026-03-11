"""Import DUN boundaries GeoJSON into Supabase table: dun_boundaries.

Usage:
  python backend_fastapi/scripts/import_dun_boundaries.py
  python backend_fastapi/scripts/import_dun_boundaries.py --geojson Selangor_DUN_2015.geojson
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from app.db.supabase_client import get_client


DEFAULT_GEOJSON = Path(__file__).resolve().parents[2] / "Selangor_DUN_2015.geojson"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import DUN boundaries into Supabase")
    parser.add_argument(
        "--geojson",
        type=Path,
        default=DEFAULT_GEOJSON,
        help="Path to Selangor DUN GeoJSON file",
    )
    return parser.parse_args()


def _slugify(text: str) -> str:
    value = re.sub(r"\s+", "-", text.strip().lower())
    value = re.sub(r"[^a-z0-9\-]+", "", value)
    value = re.sub(r"-+", "-", value)
    return value.strip("-")


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

        code_dun = str(props.get("KodDUN", "")).strip() or None
        code_par = str(props.get("KodPAR", "")).strip() or None
        dun_name = str(props.get("DUN", "")).replace("\n", " ").strip()
        parliament = str(props.get("Parliament", "")).replace("\n", " ").strip() or None
        state = str(props.get("State", "")).replace("\n", " ").strip()

        row_id = _slugify(code_dun or dun_name)
        if not row_id or not dun_name:
            continue

        row = {
            "id": row_id,
            "name": dun_name,
            "code_dun": code_dun,
            "code_par": code_par,
            "parliament": parliament,
            "state": state,
            "geometry": geometry,
            "active": True,
        }
        rows.append(row)

    if not rows:
        raise ValueError("No valid DUN boundary rows to import")

    sb = get_client()

    chunk_size = 100
    inserted = 0
    for i in range(0, len(rows), chunk_size):
        chunk = rows[i : i + chunk_size]
        sb.table("dun_boundaries").upsert(chunk, on_conflict="id").execute()
        inserted += len(chunk)

    print(f"Imported/updated {inserted} DUN boundaries from {path}")


if __name__ == "__main__":
    main()
