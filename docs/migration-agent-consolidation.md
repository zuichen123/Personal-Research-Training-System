# Agent API Migration Guide

## Overview

The legacy `/agents` endpoints have been deprecated in favor of the new `/ai/agents` endpoints. This migration consolidates agent functionality into the AI module for better organization and consistency.

## Migration Status

- **Flutter Client**: ✅ Migrated (using `/ai/agents`)
- **Backend**: ✅ Deprecation headers added
- **Timeline**: Legacy endpoints will be removed in v2.0.0

## Endpoint Mapping

### Legacy → New

| Legacy Endpoint | New Endpoint | Status |
|----------------|--------------|--------|
| `POST /agents` | `POST /ai/agents` | Deprecated |
| `GET /agents/{type}` | `GET /ai/agents` (with filtering) | Deprecated |
| `POST /agents/{id}/dispatch` | `POST /ai/sessions/{id}/messages` | Deprecated |
| `GET /agents/{id}/history` | `GET /ai/sessions/{id}/messages` | Deprecated |
| `POST /agents/head-teacher` | `POST /ai/agents` (with type) | Deprecated |
| `POST /agents/subject` | `POST /ai/agents` (with subject) | Deprecated |
| `POST /agents/{id}/bind-schedule` | `PUT /ai/sessions/{id}/schedule-binding` | Deprecated |
| `GET /agents/list` | `GET /ai/agents` | Deprecated |

## Code Examples

### Before (Legacy)

```dart
// Flutter client - OLD
final response = await api.get('/agents/list?user_id=1');
```

### After (New)

```dart
// Flutter client - NEW
final agents = await api.getAIAgents();
```

## Deprecation Headers

All legacy `/agents` endpoints now return:
- `X-Deprecated: true`
- `X-Deprecation-Notice: This endpoint is deprecated. Use /ai/agents instead. Will be removed in v2.0.0`

## Testing Checklist

- [x] Create agent via new endpoint (201)
- [x] Start session via new endpoint (201)
- [x] Send message via new endpoint (200)
- [x] View history via new endpoint (200)
- [x] Delete agent via new endpoint (204)
- [x] Verify legacy endpoints return deprecation headers

## Removal Timeline

- **v1.x**: Legacy endpoints deprecated but functional
- **v2.0.0**: Legacy endpoints removed
