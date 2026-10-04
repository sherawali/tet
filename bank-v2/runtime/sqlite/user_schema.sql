PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- This database is local-only. It contains no account, login or remote user ID.
CREATE TABLE IF NOT EXISTS user_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS question_state (
    question_id TEXT PRIMARY KEY,
    seen_count INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    incorrect_count INTEGER NOT NULL DEFAULT 0,
    skipped_count INTEGER NOT NULL DEFAULT 0,
    total_time_ms INTEGER NOT NULL DEFAULT 0,
    last_seen_at TEXT,
    last_answered_option_id TEXT,
    mastery_score REAL NOT NULL DEFAULT 0,
    local_difficulty REAL
);

CREATE TABLE IF NOT EXISTS attempts (
    id TEXT PRIMARY KEY,
    question_id TEXT NOT NULL,
    mock_session_id TEXT,
    selected_answer_json TEXT,
    correct INTEGER NOT NULL CHECK (correct IN (0, 1)),
    skipped INTEGER NOT NULL DEFAULT 0 CHECK (skipped IN (0, 1)),
    time_ms INTEGER NOT NULL DEFAULT 0,
    attempted_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_attempts_question
ON attempts(question_id, attempted_at);

CREATE TABLE IF NOT EXISTS bookmarks (
    question_id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    note TEXT
);

CREATE TABLE IF NOT EXISTS mock_sessions (
    id TEXT PRIMARY KEY,
    mode TEXT NOT NULL,
    exam TEXT NOT NULL,
    paper INTEGER NOT NULL,
    blueprint_id TEXT NOT NULL,
    language_1 TEXT,
    language_2 TEXT,
    subject_stream TEXT,
    content_bank_version INTEGER NOT NULL,
    seed TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('created', 'in-progress', 'submitted', 'abandoned')),
    started_at TEXT,
    submitted_at TEXT,
    score REAL,
    total_marks REAL,
    duration_ms INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS mock_items (
    mock_session_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    question_id TEXT NOT NULL,
    stimulus_id TEXT,
    section TEXT NOT NULL,
    PRIMARY KEY (mock_session_id, position),
    FOREIGN KEY (mock_session_id) REFERENCES mock_sessions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS topic_progress (
    topic_id TEXT PRIMARY KEY,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    total_time_ms INTEGER NOT NULL DEFAULT 0,
    mastery_score REAL NOT NULL DEFAULT 0,
    last_attempted_at TEXT
);

CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL
);
