-- +migrate Up
CREATE TABLE IF NOT EXISTS materials (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT NOT NULL,
    content_text TEXT,
    subject TEXT,
    tags_json TEXT DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_materials_user_id ON materials(user_id);
CREATE INDEX IF NOT EXISTS idx_materials_subject ON materials(subject);
CREATE INDEX IF NOT EXISTS idx_materials_file_type ON materials(file_type);

-- +migrate Down
DROP TABLE IF EXISTS materials;
