# Technical Specification: Rename to PRTS

## 1. Naming Conventions

**Use "PRTS" (uppercase) for:**
- Go package identifiers that need abbreviation
- Binary output names
- Short references in logs/comments

**Use "prts" (lowercase) for:**
- Go module path: `prts`
- Directory names
- File names
- Android package: `com.prts.app`

**Use "Personal Research & Training System" for:**
- User-facing documentation (README)
- Application titles in Flutter
- Window titles

**Keep existing for:**
- Database file name: `self-study.db` (avoid data migration)
- Notion database name: "Self-Study-Tool" (external dependency)

## 2. Code Changes

### 2.1 Go Module Path
- `go.mod`: `module self-study-tool` → `module prts`
- All Go imports: `"self-study-tool/internal/..."` → `"prts/internal/..."`

### 2.2 Flutter Package
- `pubspec.yaml`: `name: flutter_client` → `name: prts_client`
- Android: `com.selfstudy.tool.flutter_client` → `com.prts.app`

## 3. Migration Order

1. Update go.mod module name
2. Batch replace Go imports
3. Update Flutter pubspec.yaml
4. Update Android package identifier
5. Update build scripts
6. Update documentation
7. Rename root directory

## 4. Success Criteria

✅ Go builds and tests pass
✅ Flutter analyzes without errors
✅ Build scripts work
✅ Documentation updated
