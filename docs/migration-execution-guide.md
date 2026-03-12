# Migration Execution Guide (US-017)

## Overview
This guide covers the execution of the agent consolidation migration (036_consolidate_agents.sql) in production.

## Prerequisites
- Migration scripts tested in development environment
- Database backup tools available
- Staging environment available for testing
- Monitoring tools configured

## Step 1: Production Database Backup

```bash
# Create timestamped backup
BACKUP_FILE="prts_backup_$(date +%Y%m%d_%H%M%S).db"
sqlite3 production.db ".backup $BACKUP_FILE"

# Verify backup is readable
sqlite3 $BACKUP_FILE "SELECT COUNT(*) FROM agents;"
sqlite3 $BACKUP_FILE "SELECT COUNT(*) FROM agent_chats;"
```

## Step 2: Staging Migration Test

```bash
# Copy production backup to staging
cp $BACKUP_FILE staging.db

# Run migration on staging
sqlite3 staging.db < migrations/sqlite/036_consolidate_agents.sql

# Verify data integrity
sqlite3 staging.db <<EOF
SELECT 'Agents migrated:', COUNT(*) FROM ai_agents WHERE id LIKE 'legacy-%';
SELECT 'Sessions created:', COUNT(*) FROM ai_agent_sessions WHERE id LIKE 'legacy-session-%';
SELECT 'Messages migrated:', COUNT(*) FROM ai_agent_messages WHERE id LIKE 'legacy-msg-%';
SELECT 'Backup agents:', COUNT(*) FROM agents_backup;
SELECT 'Backup chats:', COUNT(*) FROM agent_chats_backup;
EOF

# Test application with staging database
# Verify all AI agent endpoints work correctly
```

## Step 3: Production Migration Execution

```bash
# Put application in maintenance mode
# Stop application servers

# Run migration
sqlite3 production.db < migrations/sqlite/036_consolidate_agents.sql

# Monitor for errors
# Check migration log
```

## Step 4: Verification Queries

```sql
-- Verify agent count matches
SELECT
    (SELECT COUNT(*) FROM agents_backup) as original_agents,
    (SELECT COUNT(*) FROM ai_agents WHERE id LIKE 'legacy-%') as migrated_agents;

-- Verify message count matches
SELECT
    (SELECT COUNT(*) FROM agent_chats_backup) as original_messages,
    (SELECT COUNT(*) FROM ai_agent_messages WHERE id LIKE 'legacy-msg-%') as migrated_messages;

-- Verify no orphaned sessions
SELECT COUNT(*) FROM ai_agent_sessions
WHERE id LIKE 'legacy-session-%'
AND agent_id NOT IN (SELECT id FROM ai_agents);

-- Verify all agent names preserved
SELECT a.name, aa.name
FROM agents_backup a
LEFT JOIN ai_agents aa ON aa.id = 'legacy-' || CAST(a.id AS TEXT)
WHERE aa.name IS NULL OR a.name != aa.name;
```

## Step 5: Rollback Procedure (if needed)

```bash
# If migration fails or data integrity issues found
sqlite3 production.db < migrations/sqlite/036_consolidate_agents_rollback.sql

# Verify rollback
sqlite3 production.db <<EOF
SELECT 'Agents restored:', COUNT(*) FROM agents;
SELECT 'Chats restored:', COUNT(*) FROM agent_chats;
EOF

# Restore from backup if rollback fails
cp $BACKUP_FILE production.db
```

## Success Criteria
- [ ] Backup created and verified readable
- [ ] Staging migration successful with data integrity verified
- [ ] Production migration executed without errors
- [ ] All verification queries pass (counts match, no orphans, names preserved)
- [ ] Application functional with migrated data

## Notes
- Keep backup files for at least 30 days
- Monitor application logs for any agent-related errors after migration
- Legacy endpoints will continue to work (with deprecation headers) until v2.0.0
