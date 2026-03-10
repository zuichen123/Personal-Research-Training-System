-- Create user portraits table for AI profiling
CREATE TABLE IF NOT EXISTS user_portraits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence REAL DEFAULT 1.0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    UNIQUE(user_id, category, key)
);

CREATE INDEX idx_user_portraits_user_category ON user_portraits(user_id, category);
