-- Create prompt templates table for AI prompt management
CREATE TABLE IF NOT EXISTS prompt_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    system_role TEXT NOT NULL,
    task_description TEXT NOT NULL,
    output_format TEXT NOT NULL,
    examples TEXT,
    variables TEXT,
    version INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prompt_templates_category ON prompt_templates(category);
CREATE INDEX idx_prompt_templates_name ON prompt_templates(name);
