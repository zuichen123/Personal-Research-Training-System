-- Drop legacy agent tables
-- These tables have been migrated to ai_agents, ai_agent_sessions, and ai_agent_messages
-- Run this migration after verifying the data migration was successful

DROP TABLE IF EXISTS agent_chats;
DROP TABLE IF EXISTS agents;

-- Also drop backup tables if they exist
DROP TABLE IF EXISTS agent_chats_backup;
DROP TABLE IF EXISTS agents_backup;
