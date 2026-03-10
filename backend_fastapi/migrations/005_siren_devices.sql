-- 005: IoT siren device management & activation log
-- Supports registration, triggering, and audit-trail for community sirens.

CREATE TABLE IF NOT EXISTS siren_devices (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    radius_km     DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    endpoint_url  TEXT,                         -- HTTP endpoint to trigger the siren
    api_key       TEXT,                         -- auth key sent with trigger request
    status        TEXT NOT NULL DEFAULT 'idle', -- idle | active | offline | maintenance
    registered_by TEXT,                         -- user_id of admin who added it
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS siren_activations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    siren_id        UUID NOT NULL REFERENCES siren_devices(id) ON DELETE CASCADE,
    warning_id      UUID,                       -- the warning that triggered it (nullable for manual)
    trigger_type    TEXT NOT NULL DEFAULT 'manual',  -- manual | auto | api
    triggered_by    TEXT,                        -- user_id or 'scheduler'
    triggered_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    stopped_at      TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'triggered', -- triggered | acknowledged | stopped | failed
    error_reason    TEXT
);

CREATE INDEX IF NOT EXISTS idx_siren_devices_status ON siren_devices(status);
CREATE INDEX IF NOT EXISTS idx_siren_activations_siren ON siren_activations(siren_id);
CREATE INDEX IF NOT EXISTS idx_siren_activations_warning ON siren_activations(warning_id);
