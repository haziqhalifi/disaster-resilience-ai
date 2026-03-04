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
    hashed_password TEXT      NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
