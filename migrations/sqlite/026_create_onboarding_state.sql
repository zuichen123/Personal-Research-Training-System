-- Create onboarding state table for tracking user onboarding progress
CREATE TABLE IF NOT EXISTS onboarding_state (
    user_id INTEGER PRIMARY KEY,
    current_step INTEGER DEFAULT 0,
    responses TEXT,
    completed BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE CASCADE
);

CREATE INDEX idx_onboarding_state_completed ON onboarding_state(completed);
