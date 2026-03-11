-- 006: AI-driven adaptive quiz & learning progress
-- Tracks quiz attempts, individual answers, and per-module mastery

-- Quiz attempts: one row per quiz session
CREATE TABLE IF NOT EXISTS quiz_attempts (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID NOT NULL,
    hazard_type     TEXT NOT NULL,            -- flood, landslide, earthquake, storm, tsunami, haze
    score           INT NOT NULL DEFAULT 0,
    total_questions INT NOT NULL DEFAULT 0,
    percentage      REAL NOT NULL DEFAULT 0,
    difficulty_avg  REAL NOT NULL DEFAULT 1,  -- average difficulty of questions asked
    phase_scores    JSONB DEFAULT '{}',       -- {"before": 0.8, "during": 0.5, "after": 1.0}
    weak_areas      JSONB DEFAULT '[]',       -- ["during"]
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Individual answers per attempt
CREATE TABLE IF NOT EXISTS quiz_answers (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    attempt_id      UUID NOT NULL REFERENCES quiz_attempts(id) ON DELETE CASCADE,
    question_index  INT NOT NULL,
    question_text   TEXT NOT NULL,
    phase           TEXT NOT NULL,            -- before / during / after
    difficulty      INT NOT NULL DEFAULT 1,
    selected_answer TEXT NOT NULL,            -- A / B / C / D
    correct_answer  TEXT NOT NULL,
    is_correct      BOOLEAN NOT NULL DEFAULT false,
    explanation     TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Aggregated learning progress per user per hazard (updated after each quiz)
CREATE TABLE IF NOT EXISTS learning_progress (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID NOT NULL,
    hazard_type     TEXT NOT NULL,
    total_attempts  INT NOT NULL DEFAULT 0,
    best_score      REAL NOT NULL DEFAULT 0,  -- best percentage
    latest_score    REAL NOT NULL DEFAULT 0,
    mastery_level   REAL NOT NULL DEFAULT 0,  -- 0-1 weighted mastery from AI engine
    phase_scores    JSONB DEFAULT '{}',       -- averaged per-phase scores
    weak_areas      JSONB DEFAULT '[]',
    last_attempt_at TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, hazard_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user    ON quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_hazard  ON quiz_attempts(user_id, hazard_type);
CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt  ON quiz_answers(attempt_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_user ON learning_progress(user_id);
