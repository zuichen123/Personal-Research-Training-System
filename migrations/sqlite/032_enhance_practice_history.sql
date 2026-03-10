-- Enhance practice_history with detailed results
ALTER TABLE practice_history ADD COLUMN my_answer TEXT;
ALTER TABLE practice_history ADD COLUMN is_correct BOOLEAN;
ALTER TABLE practice_history ADD COLUMN score INTEGER;
ALTER TABLE practice_history ADD COLUMN grading_detail TEXT;

CREATE INDEX idx_practice_history_correct ON practice_history(is_correct);
