# API Standards

## Error Response Format

All API errors follow this JSON schema:

```json
{
  "code": "string",           // Error code (e.g., "VALIDATION_ERROR", "NOT_FOUND")
  "message": "string",        // Human-readable error message
  "details": {},              // Additional error context (object)
  "trace_id": "string"        // Request trace ID for debugging
}
```

### Common Error Codes
- `VALIDATION_ERROR`: Invalid input data
- `NOT_FOUND`: Resource not found
- `UNAUTHORIZED`: Authentication required
- `FORBIDDEN`: Insufficient permissions
- `INTERNAL_ERROR`: Server error

## Pagination Standard

Cursor-based pagination for list endpoints:

```json
{
  "data": [...],
  "cursor": "string",         // Opaque cursor for next page
  "has_more": boolean,        // True if more results exist
  "limit": number             // Items per page (requested)
}
```

### Usage
- Request: `GET /api/resource?limit=20&cursor=abc123`
- Response includes `cursor` for next page
- `has_more: false` indicates last page

## Success Response Format

Standard wrapper for successful responses:

```json
{
  "data": {},                 // Response payload (object or array)
  "meta": {
    "timestamp": "string",    // ISO 8601 timestamp
    "trace_id": "string"      // Request trace ID
  }
}
```

### Examples
```json
// Single resource
{"data": {"id": "123", "name": "Item"}, "meta": {"timestamp": "2026-03-12T04:19:00Z", "trace_id": "abc"}}

// List with pagination
{"data": [...], "cursor": "xyz", "has_more": true, "limit": 20, "meta": {...}}
```

## API Versioning Strategy

### URL-Based Versioning
- Format: `/api/v1/resource`, `/api/v2/resource`
- Current version: `v1`
- Default: Latest stable version if no version specified

### Migration Plan
1. **Deprecation Notice**: 90 days before removal
   - Add `X-Deprecated: true` header
   - Include `X-Sunset: <date>` header
   - Document in API changelog

2. **Parallel Support**: Run old and new versions simultaneously
   - Maintain v1 while v2 is in beta
   - Allow gradual client migration

3. **Breaking Changes**: Require new version
   - Schema changes (field removal/rename)
   - Behavior changes (validation rules)
   - Authentication changes

4. **Non-Breaking Changes**: Same version
   - New optional fields
   - New endpoints
   - Performance improvements

### Version Lifecycle
- **Beta**: `/api/v2-beta/` (unstable, may change)
- **Stable**: `/api/v2/` (production-ready)
- **Deprecated**: 90-day sunset period
- **Removed**: After sunset date
