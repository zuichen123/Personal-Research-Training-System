-- Create difficulty rubrics table
CREATE TABLE IF NOT EXISTS difficulty_rubrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject TEXT NOT NULL,
    level INTEGER NOT NULL CHECK(level BETWEEN 1 AND 10),
    description TEXT NOT NULL,
    example_question TEXT,
    gaokao_equivalent TEXT,
    created_by TEXT DEFAULT 'ai',
    UNIQUE(subject, level)
);

CREATE INDEX idx_difficulty_rubrics_subject ON difficulty_rubrics(subject);
