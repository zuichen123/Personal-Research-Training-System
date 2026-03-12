-- Rollback: Restore legacy agents tables from backup
-- This script reverses the consolidation migration

-- Step 1: Drop migrated data from ai_* tables
-- Only drop legacy-prefixed entries to preserve any new data
DELETE FROM ai_agent_messages WHERE id LIKE 'legacy-msg-%';
DELETE FROM ai_agent_sessions WHERE id LIKE 'legacy-session-%';
DELETE FROM ai_agents WHERE id LIKE 'legacy-%';

-- Step 2: Restore agents table from backup
INSERT OR REPLACE INTO agents (
    id,
    user_id,
    type,
    subject,
    name,
    prompt_template_id,
    context,
    created_at
)
SELECT
    id,
    user_id,
    type,
    subject,
    name,
    prompt_template_id,
    context,
    created_at
FROM agents_backup;

-- Step 3: Restore agent_chats table from backup
INSERT OR REPLACE INTO agent_chats (
    id,
    agent_id,
    role,
    content,
    created_at
)
SELECT
    id,
    agent_id,
    role,
    content,
    created_at
FROM agent_chats_backup;

-- Step 4: Verify counts match
-- This will be checked by the application after rollback
SELECT
    (SELECT COUNT(*) FROM agents) as agents_count,
    (SELECT COUNT(*) FROM agents_backup) as agents_backup_count,
    (SELECT COUNT(*) FROM agent_chats) as chats_count,
    (SELECT COUNT(*) FROM agent_chats_backup) as chats_backup_count;

-- Step 5: Drop backup tables (optional, comment out if you want to keep backups)
-- DROP TABLE IF EXISTS agents_backup;
-- DROP TABLE IF EXISTS agent_chats_backup;
