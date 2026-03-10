-- Enhance user_profiles table for personalized learning
ALTER TABLE user_profiles ADD COLUMN learning_goals TEXT;
ALTER TABLE user_profiles ADD COLUMN self_assessment TEXT;
ALTER TABLE user_profiles ADD COLUMN availability TEXT;
ALTER TABLE user_profiles ADD COLUMN learning_style TEXT;
ALTER TABLE user_profiles ADD COLUMN onboarding_completed BOOLEAN DEFAULT 0;
