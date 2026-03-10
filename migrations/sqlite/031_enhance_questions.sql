-- Enhance questions table with difficulty and source tracking
ALTER TABLE questions ADD COLUMN difficulty_level INTEGER DEFAULT 5 CHECK(difficulty_level BETWEEN 1 AND 10);
ALTER TABLE questions ADD COLUMN source_agent_id INTEGER;
ALTER TABLE questions ADD COLUMN source_lesson_id INTEGER;

CREATE INDEX idx_questions_difficulty ON questions(difficulty_level);
CREATE INDEX idx_questions_source_agent ON questions(source_agent_id);
