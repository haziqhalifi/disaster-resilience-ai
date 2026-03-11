-- =============================================================================
-- Migration 009: DUN Boundaries (GeoJSON)
--
-- Stores Dewan Undangan Negeri (DUN) polygons for finer-grained hazard mapping.
-- Geometry is stored as GeoJSON (JSONB) to keep deployment simple.
-- =============================================================================

CREATE TABLE IF NOT EXISTS dun_boundaries (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    code_dun     TEXT,
    code_par     TEXT,
    parliament   TEXT,
    state        TEXT NOT NULL DEFAULT '',
    geometry     JSONB NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dun_boundaries_active
    ON dun_boundaries(active);

CREATE INDEX IF NOT EXISTS idx_dun_boundaries_state
    ON dun_boundaries(state);

CREATE INDEX IF NOT EXISTS idx_dun_boundaries_code_dun
    ON dun_boundaries(code_dun);

CREATE INDEX IF NOT EXISTS idx_dun_boundaries_geometry_gin
    ON dun_boundaries USING GIN (geometry);
