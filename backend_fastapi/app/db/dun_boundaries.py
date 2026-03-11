"""DUN boundaries store backed by Supabase (table: dun_boundaries)."""

from __future__ import annotations

from typing import TypedDict

from app.db.supabase_client import get_client


class DUNBoundaryRecord(TypedDict):
    id: str
    name: str
    code_dun: str | None
    code_par: str | None
    parliament: str | None
    state: str
    geometry: dict
    active: bool


def list_dun_boundaries(*, active_only: bool = True) -> list[DUNBoundaryRecord]:
    sb = get_client()
    query = sb.table("dun_boundaries").select(
        "id,name,code_dun,code_par,parliament,state,geometry,active"
    )
    if active_only:
        query = query.eq("active", True)
    res = query.execute()
    return res.data
