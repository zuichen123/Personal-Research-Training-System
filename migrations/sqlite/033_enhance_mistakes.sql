-- Enhance mistakes table with unit and AI analysis
ALTER TABLE mistakes ADD COLUMN unit TEXT;
ALTER TABLE mistakes ADD COLUMN lesson_id INTEGER;
ALTER TABLE mistakes ADD COLUMN analysis TEXT;

CREATE INDEX idx_mistakes_unit ON mistakes(unit);
CREATE INDEX idx_mistakes_lesson ON mistakes(lesson_id);
