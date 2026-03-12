# Developer Onboarding Guide

## Prerequisites

- Go 1.23+
- Flutter SDK 3.0+
- Git
- SQLite (included with Go)

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd Self-Study-Tool
```

### 2. Backend Setup

```bash
# Install Go dependencies
go mod download

# Run backend
go run ./cmd/server
```

Backend will start on `http://localhost:8080`

### 3. Flutter Client Setup

```bash
cd apps/flutter_client
flutter pub get
flutter run
```

## Project Structure

```
Self-Study-Tool/
├── cmd/server/          # Backend entry point
├── internal/
│   ├── bootstrap/       # App initialization
│   ├── modules/         # Business modules (ai, question, practice, etc.)
│   └── shared/          # Shared utilities
├── apps/flutter_client/ # Flutter client
├── migrations/          # Database migrations
├── prompts/            # AI prompt templates
└── docs/               # Documentation
```

## Development Workflow

### Backend Development

```bash
# Run tests
go test ./...

# Run with hot reload (install air first)
air

# Build
go build -o prts ./cmd/server
```

### Flutter Development

```bash
cd apps/flutter_client

# Run tests
flutter test

# Analyze code
flutter analyze

# Build for platform
flutter build windows
flutter build web
flutter build apk
```

## API Documentation

- OpenAPI spec: `docs/openapi.yaml`
- API standards: `docs/api-standards.md`
- Migration guides: `docs/migration-*.md`

## Component Library

Flutter UI components are in `apps/flutter_client/lib/widgets/common/`:
- AppButton, AppTextField, AppCard
- AppDialog, AppBottomSheet
- AppLoadingIndicator, AppErrorView, AppEmptyState

See Flutter client README for usage examples.

## Database

- SQLite database: `./data/self-study.db`
- Migrations: `migrations/sqlite/`
- Run migrations automatically on startup

## Environment Variables

Create `.env` file (optional):

```bash
# AI Provider
AI_PROVIDER=mock
AI_OPENAI_API_KEY=your-key-here

# Server
APP_PORT=8080
APP_ENV=development
```

See main README.md for full list of environment variables.

## Common Tasks

### Add New API Endpoint

1. Create handler in `internal/modules/<module>/handler.go`
2. Register route in handler's `RegisterRoutes` method
3. Update `docs/openapi.yaml`
4. Add Flutter API method in `lib/services/api_service.dart`

### Add New Flutter Screen

1. Create screen in `lib/screens/`
2. Add route in navigation
3. Use component library widgets from `lib/widgets/common/`

### Run Database Migration

```bash
# Migrations run automatically on startup
# Or manually:
sqlite3 data/self-study.db < migrations/sqlite/XXX_migration.sql
```

## Troubleshooting

**Backend won't start**: Check if port 8080 is available
**Flutter build fails**: Run `flutter clean && flutter pub get`
**Database locked**: Close other connections to the database file

## Next Steps

1. Read `docs/api-standards.md` for API conventions
2. Check `CLAUDE.md` for project collaboration guidelines
3. Review existing modules in `internal/modules/` for patterns
4. Join team communication channels
