"""District boundaries store backed by Supabase (table: district_boundaries)."""

from __future__ import annotations

from typing import TypedDict

from app.db.supabase_client import get_client


class DistrictBoundaryRecord(TypedDict):
    id: str
    name: str
    state: str
    code_state: int | None
    geometry: dict
    active: bool


def list_district_boundaries(*, active_only: bool = True) -> list[DistrictBoundaryRecord]:
    sb = get_client()
    query = sb.table("district_boundaries").select("id,name,state,code_state,geometry,active")
    if active_only:
        query = query.eq("active", True)
    res = query.execute()
    return res.data
