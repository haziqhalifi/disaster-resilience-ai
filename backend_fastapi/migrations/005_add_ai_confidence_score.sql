-- 005: Add AI confidence_score column to reports table
-- This column stores the AI-computed credibility score for each community report.
-- The score is set on submission and updated by the scheduler's AI review job.

ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS confidence_score DOUBLE PRECISION
    DEFAULT NULL
    CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1));

COMMENT ON COLUMN reports.confidence_score IS
    'AI-predicted credibility score (0.0–1.0). Set by ReportCredibilityRF model.';
