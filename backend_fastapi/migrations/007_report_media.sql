-- Migration 007: Add media URLs for community reports
-- Run in Supabase SQL editor.

ALTER TABLE reports
ADD COLUMN IF NOT EXISTS media_urls JSONB NOT NULL DEFAULT '[]'::jsonb;
