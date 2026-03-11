-- =============================================================================
-- Migration 008: District Boundaries (GeoJSON)
--
-- Stores Malaysia district polygons for area-based hazard mapping.
-- Geometry is stored as GeoJSON (JSONB) to keep deployment simple.
-- =============================================================================

CREATE TABLE IF NOT EXISTS district_boundaries (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    state        TEXT NOT NULL DEFAULT '',
    code_state   INT,
    geometry     JSONB NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_district_boundaries_active
    ON district_boundaries(active);

CREATE INDEX IF NOT EXISTS idx_district_boundaries_state
    ON district_boundaries(state);

CREATE INDEX IF NOT EXISTS idx_district_boundaries_geometry_gin
    ON district_boundaries USING GIN (geometry);
