-- 006: Fix confidence_score column type (INT → DOUBLE PRECISION)
--
-- Root cause: migration 001 created confidence_score as INT.
-- If migration 002 (which drops it) was skipped or run out of order,
-- migration 005's "ADD COLUMN IF NOT EXISTS" silently did nothing,
-- leaving the column as INT — causing "invalid input syntax for type integer"
-- when the AI stores float scores like 0.1262.
--
-- This migration is idempotent and handles all states.
-- Run in Supabase Dashboard → SQL Editor → New Query

DO $$
BEGIN
  -- Case 1: column exists but is NOT double precision → convert it
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports'
      AND column_name = 'confidence_score'
      AND data_type != 'double precision'
  ) THEN
    ALTER TABLE reports
      ALTER COLUMN confidence_score TYPE DOUBLE PRECISION
      USING confidence_score::DOUBLE PRECISION;

    RAISE NOTICE 'confidence_score column converted to DOUBLE PRECISION';
  END IF;

  -- Case 2: column does not exist at all → add it
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports'
      AND column_name = 'confidence_score'
  ) THEN
    ALTER TABLE reports
      ADD COLUMN confidence_score DOUBLE PRECISION
      DEFAULT NULL
      CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1));

    RAISE NOTICE 'confidence_score column added as DOUBLE PRECISION';
  END IF;

  -- Case 3: column already exists as double precision → nothing to do
END $$;

COMMENT ON COLUMN reports.confidence_score IS
  'AI-predicted credibility score (0.0–1.0). Set by ReportCredibilityRF model.';
