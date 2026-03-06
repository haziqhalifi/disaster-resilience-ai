-- ==========================================================================
-- Disaster Resilience AI — Supabase table migrations
--
-- Run this in the Supabase Dashboard → SQL Editor (or via supabase CLI).
-- ==========================================================================

-- ── 1. Users ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.users (
    id            TEXT PRIMARY KEY,
    username      TEXT        NOT NULL UNIQUE,
    email         TEXT        NOT NULL UNIQUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- If migrating from legacy local-auth schema, remove password hash storage.
ALTER TABLE public.users
    DROP COLUMN IF EXISTS hashed_password;

-- Index for fast email look-ups during sign-in
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users (email);


-- ── 2. Warnings (Hyper-Local Early Warning system) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.warnings (
    id            TEXT PRIMARY KEY,
    title         TEXT        NOT NULL,
    description   TEXT        NOT NULL,
    hazard_type   TEXT        NOT NULL CHECK (hazard_type IN ('flood', 'landslide', 'typhoon', 'earthquake')),
    alert_level   TEXT        NOT NULL CHECK (alert_level IN ('advisory', 'observe', 'warning', 'evacuate')),
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    radius_km     DOUBLE PRECISION NOT NULL CHECK (radius_km > 0),
    source        TEXT        NOT NULL DEFAULT 'system',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    active        BOOLEAN     NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_warnings_active ON public.warnings (active)
    WHERE active = true;


-- ── 3. Devices (user location & push/SMS registration) ─────────────────────

CREATE TABLE IF NOT EXISTS public.devices (
    user_id       TEXT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    latitude      DOUBLE PRECISION,
    longitude     DOUBLE PRECISION,
    fcm_token     TEXT,
    phone_number  TEXT,
    updated_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_devices_location ON public.devices (latitude, longitude)
    WHERE latitude IS NOT NULL;


-- ── Row Level Security (RLS) — enable and set policies ──────────────────────
-- These policies allow the service-role key (used by the backend) full access.
-- Adjust as needed if you expose the Supabase anon key to the client directly.

ALTER TABLE public.users    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices  ENABLE ROW LEVEL SECURITY;

-- Service-role bypass (the backend's SUPABASE_KEY should be the service_role key)
CREATE POLICY "Service role full access" ON public.users
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.warnings
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.devices
    FOR ALL USING (true) WITH CHECK (true);


-- ── 4. Risk Zones (AI Risk Mapping) ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.risk_zones (
    id            TEXT PRIMARY KEY,
    name          TEXT        NOT NULL,
    zone_type     TEXT        NOT NULL CHECK (zone_type IN ('danger', 'warning', 'safe')),
    hazard_type   TEXT        NOT NULL CHECK (hazard_type IN ('flood', 'landslide', 'typhoon', 'earthquake')),
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    radius_km     DOUBLE PRECISION NOT NULL CHECK (radius_km > 0),
    risk_score    DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (risk_score >= 0 AND risk_score <= 1),
    description   TEXT        NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    active        BOOLEAN     NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_risk_zones_active ON public.risk_zones (active)
    WHERE active = true;


-- ── 5. Evacuation Centres ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.evacuation_centres (
    id                TEXT PRIMARY KEY,
    name              TEXT        NOT NULL,
    latitude          DOUBLE PRECISION NOT NULL,
    longitude         DOUBLE PRECISION NOT NULL,
    capacity          INTEGER     NOT NULL CHECK (capacity > 0),
    current_occupancy INTEGER     NOT NULL DEFAULT 0 CHECK (current_occupancy >= 0),
    contact_phone     TEXT,
    address           TEXT        NOT NULL DEFAULT '',
    active            BOOLEAN     NOT NULL DEFAULT true
);


-- ── 6. Evacuation Routes ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.evacuation_routes (
    id                TEXT PRIMARY KEY,
    name              TEXT        NOT NULL,
    start_lat         DOUBLE PRECISION NOT NULL,
    start_lon         DOUBLE PRECISION NOT NULL,
    end_lat           DOUBLE PRECISION NOT NULL,
    end_lon           DOUBLE PRECISION NOT NULL,
    waypoints         JSONB       NOT NULL DEFAULT '[]',
    distance_km       DOUBLE PRECISION NOT NULL CHECK (distance_km > 0),
    estimated_minutes INTEGER     NOT NULL CHECK (estimated_minutes > 0),
    elevation_gain_m  DOUBLE PRECISION NOT NULL DEFAULT 0,
    status            TEXT        NOT NULL DEFAULT 'clear' CHECK (status IN ('clear', 'partial', 'blocked')),
    active            BOOLEAN     NOT NULL DEFAULT true
);


-- ── RLS for new tables ──────────────────────────────────────────────────────

ALTER TABLE public.risk_zones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evacuation_centres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evacuation_routes  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.risk_zones
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.evacuation_centres
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.evacuation_routes
    FOR ALL USING (true) WITH CHECK (true);


-- ── 7. User Profiles (Emergency & Personal Info) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id                        TEXT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    full_name                      TEXT,
    phone_number                   TEXT,
    blood_type                     TEXT,
    allergies                      TEXT NOT NULL DEFAULT '',
    medical_conditions             TEXT NOT NULL DEFAULT '',
    emergency_contact_name         TEXT,
    emergency_contact_relationship TEXT,
    emergency_contact_phone        TEXT,
    updated_at                     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.user_profiles
    FOR ALL USING (true) WITH CHECK (true);
