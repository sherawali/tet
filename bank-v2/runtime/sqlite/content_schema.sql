PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS content_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS section_stores (
    database_id TEXT PRIMARY KEY,
    exam TEXT NOT NULL CHECK (exam IN ('ctet', 'utet')),
    paper INTEGER NOT NULL CHECK (paper IN (1, 2)),
    section TEXT NOT NULL,
    language TEXT,
    language_slot INTEGER CHECK (language_slot IN (1, 2) OR language_slot IS NULL),
    content_mode TEXT NOT NULL CHECK (content_mode IN ('bilingual', 'language-specific')),
    version INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'empty'
);

CREATE TABLE IF NOT EXISTS topics (
    id TEXT PRIMARY KEY,
    parent_id TEXT,
    kind TEXT NOT NULL CHECK (kind IN ('topic', 'subtopic', 'concept')),
    exam TEXT NOT NULL,
    paper INTEGER NOT NULL,
    section TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    status TEXT NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES topics(id)
);

CREATE TABLE IF NOT EXISTS assets (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS stimuli (
    id TEXT PRIMARY KEY,
    database_id TEXT NOT NULL,
    type TEXT NOT NULL,
    language TEXT,
    language_slot INTEGER,
    selection_policy TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    status TEXT NOT NULL,
    FOREIGN KEY (database_id) REFERENCES section_stores(database_id)
);

CREATE TABLE IF NOT EXISTS questions (
    id TEXT PRIMARY KEY,
    database_id TEXT NOT NULL,
    exam TEXT NOT NULL,
    paper INTEGER NOT NULL,
    section TEXT NOT NULL,
    language TEXT,
    language_slot INTEGER,
    type TEXT NOT NULL,
    source_type TEXT NOT NULL,
    stimulus_id TEXT,
    editorial_difficulty TEXT,
    status TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    updated_bank_version INTEGER NOT NULL,
    FOREIGN KEY (database_id) REFERENCES section_stores(database_id),
    FOREIGN KEY (stimulus_id) REFERENCES stimuli(id)
);

CREATE INDEX IF NOT EXISTS idx_questions_scope
ON questions(exam, paper, section, language_slot, language, status);

CREATE INDEX IF NOT EXISTS idx_questions_stimulus
ON questions(stimulus_id);

CREATE TABLE IF NOT EXISTS question_topics (
    question_id TEXT NOT NULL,
    topic_id TEXT NOT NULL,
    PRIMARY KEY (question_id, topic_id),
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
    FOREIGN KEY (topic_id) REFERENCES topics(id)
);

CREATE TABLE IF NOT EXISTS paper_forms (
    id TEXT PRIMARY KEY,
    exam TEXT NOT NULL,
    paper INTEGER NOT NULL,
    exam_date TEXT NOT NULL,
    shift INTEGER,
    verification_status TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    updated_bank_version INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS appearances (
    id TEXT PRIMARY KEY,
    question_id TEXT NOT NULL,
    paper_form_id TEXT NOT NULL,
    section TEXT NOT NULL,
    language TEXT,
    language_slot INTEGER,
    question_number INTEGER NOT NULL,
    official_option_id TEXT,
    verification_status TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    FOREIGN KEY (question_id) REFERENCES questions(id),
    FOREIGN KEY (paper_form_id) REFERENCES paper_forms(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_appearances_paper_order
ON appearances(paper_form_id, question_number);

CREATE INDEX IF NOT EXISTS idx_appearances_question
ON appearances(question_id);

CREATE TABLE IF NOT EXISTS mock_blueprints (
    id TEXT PRIMARY KEY,
    exam TEXT NOT NULL,
    paper INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    updated_bank_version INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS installed_packs (
    pack_id TEXT PRIMARY KEY,
    version INTEGER NOT NULL,
    sha256 TEXT NOT NULL,
    installed_at TEXT NOT NULL,
    question_count INTEGER NOT NULL,
    asset_count INTEGER NOT NULL
);
