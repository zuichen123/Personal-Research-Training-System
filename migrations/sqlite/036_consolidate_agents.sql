-- Migration: Consolidate legacy agents into AI module
-- This migration moves data from the legacy agents/agent_chats tables
-- into the new ai_agents/ai_agent_sessions/ai_agent_messages tables

-- Step 1: Create backup tables
CREATE TABLE IF NOT EXISTS agents_backup AS SELECT * FROM agents;
CREATE TABLE IF NOT EXISTS agent_chats_backup AS SELECT * FROM agent_chats;

-- Step 2: Migrate agents to ai_agents
-- Map legacy agent fields to new ai_agents schema
INSERT INTO ai_agents (
    id,
    name,
    protocol,
    primary_config_json,
    fallback_config_json,
    system_prompt,
    intent_capabilities_json,
    enabled,
    created_at,
    updated_at
)
SELECT
    'legacy-' || CAST(id AS TEXT) as id,
    name,
    'mock' as protocol,
    '{}' as primary_config_json,
    '{}' as fallback_config_json,
    COALESCE(context, '') as system_prompt,
    '["chat"]' as intent_capabilities_json,
    1 as enabled,
    created_at,
    created_at as updated_at
FROM agents
WHERE NOT EXISTS (
    SELECT 1 FROM ai_agents WHERE ai_agents.id = 'legacy-' || CAST(agents.id AS TEXT)
);

-- Step 3: Create sessions for each legacy agent
-- Each agent gets one session to hold its chat history
INSERT INTO ai_agent_sessions (
    id,
    agent_id,
    title,
    context_summary_text,
    context_summary_meta_json,
    context_summary_updated_at,
    context_summary_message_count,
    created_at,
    updated_at,
    archived_at
)
SELECT
    'legacy-session-' || CAST(id AS TEXT) as id,
    'legacy-' || CAST(id AS TEXT) as agent_id,
    'Legacy Chat History' as title,
    '' as context_summary_text,
    '{}' as context_summary_meta_json,
    NULL as context_summary_updated_at,
    0 as context_summary_message_count,
    created_at,
    created_at as updated_at,
    NULL as archived_at
FROM agents
WHERE NOT EXISTS (
    SELECT 1 FROM ai_agent_sessions WHERE ai_agent_sessions.id = 'legacy-session-' || CAST(agents.id AS TEXT)
);

-- Step 4: Migrate chat history to ai_agent_messages
INSERT INTO ai_agent_messages (
    id,
    session_id,
    role,
    content,
    intent_json,
    pending_confirmation_json,
    provider_used,
    model_used,
    fallback_used,
    latency_ms,
    created_at
)
SELECT
    'legacy-msg-' || CAST(agent_chats.id AS TEXT) as id,
    'legacy-session-' || CAST(agent_chats.agent_id AS TEXT) as session_id,
    agent_chats.role,
    agent_chats.content,
    '' as intent_json,
    '' as pending_confirmation_json,
    '' as provider_used,
    '' as model_used,
    0 as fallback_used,
    0 as latency_ms,
    agent_chats.created_at
FROM agent_chats
WHERE NOT EXISTS (
    SELECT 1 FROM ai_agent_messages WHERE ai_agent_messages.id = 'legacy-msg-' || CAST(agent_chats.id AS TEXT)
);
