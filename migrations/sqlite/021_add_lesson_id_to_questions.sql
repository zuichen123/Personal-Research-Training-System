-- Add lesson_id column to questions table for reverse navigation to course lessons
ALTER TABLE questions ADD COLUMN lesson_id TEXT DEFAULT '';
