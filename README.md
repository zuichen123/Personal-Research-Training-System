# Personal Research & Training System (PRTS)

License: AGPL-3.0-or-later

基于 Go + Flutter 的智能化自学管理器。

- 后端：Go + SQLite（单二进制开箱即用）
- 客户端：Flutter（Windows/Linux/macOS/Android/iOS/Web）
- AI：`mock | openai | gemini | claude`，可配置回退到 mock
- 日志：结构化 JSON，`trace_id` 全链路，支持控制台与滚动文件

架构文档见：[架构.md](./架构.md)

## 项目结构

- `cmd/server`：后端启动入口
- `internal/bootstrap`：应用装配、路由注册、AI 控制入口
- `internal/modules`：业务模块（question / practice / plan / ai / profile 等）
- `internal/shared`：通用错误、HTTP 响应、基础设施辅助
- `apps/flutter_client`：Flutter 客户端
  - `lib/widgets/common/`：统一 UI 组件库（AppButton, AppTextField, AppCard, AppDialog, AppBottomSheet 等）
- `prompts/ai`：AI 提示词分段文件
- `scripts`：常用构建脚本
- `docs/`：API 文档、迁移指南、开发者入门
- `TODO.md`：已废弃，仅保留 Notion 迁移说明

## 开发前提

- Go 1.23+
- Flutter SDK（用于 `apps/flutter_client`）
- Windows 本地联调默认：后端 `http://127.0.0.1:8080/api/v1`
- Android 模拟器默认：`http://10.0.2.2:8080/api/v1`

## 快速启动后端

```bash
go run ./cmd/server
```

默认端口：`8080`

## 启动 Flutter 客户端

```bash
cd apps/flutter_client
flutter pub get
flutter run
```

如需显式指定后端地址：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

Windows 一键联调可直接使用：

```bat
run-test.bat
```

该脚本会：

- 新开窗口启动 `go run ./cmd/server`
- 在当前窗口启动 `flutter run`
- 默认使用 Windows 设备，可透传 `-d` / `--device-id`

## 常用脚本

### 构建后端

```powershell
./scripts/build-cross.ps1
```

```bash
./scripts/build-cross.sh
```

### 构建 Flutter 客户端

```powershell
./scripts/build-client.ps1 -Targets windows
./scripts/build-client.ps1 -Targets web,apk -ApiBaseUrl http://127.0.0.1:8080/api/v1
./scripts/build-client.ps1 -Targets all -DryRun
```

```bash
./scripts/build-client.sh --target windows
./scripts/build-client.sh --target web --target apk --api-base-url http://127.0.0.1:8080/api/v1
./scripts/build-client.sh --target all --dry-run
```

说明：

- PowerShell 与 Bash 版本能力对齐，适合不同终端环境
- 支持目标：`windows`、`web`、`apk`、`all`
- 构建产物统一整理到 `dist/flutter-client`
- `-DryRun` / `--dry-run` 仅打印命令，不实际执行
- `-SkipPubGet` / `--skip-pub-get` 可在依赖已准备好时跳过 `flutter pub get`

## API 文档

项目 API 以 Notion 清单为准，避免 README 与代码双维护后漂移：

- Notion API 清单：`https://www.notion.so/31cba63208ec810ebdebd78d08036fe3`

当前主要模块包括：

- `System`：健康检查
- `Question / Mistake / Practice / Resource / Plan / Pomodoro / Profile`
- `AI`：provider、prompts、agents、sessions、artifacts、questions、learning、grade/evaluate/score

> API 支持链路追踪请求头：`X-Trace-ID`（服务端会回传同名响应头）

## 存储

- 数据库：`SQLITE_PATH`（默认 `./data/self-study.db`）
- 文件内容：`resources.data`（BLOB）
- 后端日志文件：`LOG_FILE_PATH`（默认 `./data/logs/app.log`）

## 环境变量

### 服务基础

- `APP_PORT` 默认 `8080`
- `HTTP_READ_TIMEOUT` 默认 `10s`
- `HTTP_WRITE_TIMEOUT` 默认 `15s`
- `HTTP_SHUTDOWN_TIMEOUT` 默认 `10s`
- `APP_ENV` 默认 `development`
- `SQLITE_PATH` 默认 `./data/self-study.db`
- `UPLOAD_MAX_BYTES` 默认 `20971520`（20MB）

### AI

- `AI_PROVIDER` 默认 `mock`（支持：`mock/openai/gemini/claude`）
- `AI_MOCK_LATENCY` 默认 `200ms`
- `AI_HTTP_TIMEOUT` 默认 `20s`
- `AI_FALLBACK_TO_MOCK` 默认 `true`
- `AI_OPENAI_BASE_URL` 默认 `https://api.openai.com/v1`
- `AI_OPENAI_API_KEY` 默认空
- `AI_OPENAI_MODEL` 默认 `gpt-4o-mini`
- `AI_GEMINI_API_KEY` 默认空
- `AI_GEMINI_MODEL` 默认 `gemini-1.5-flash`
- `AI_CLAUDE_API_KEY` 默认空
- `AI_CLAUDE_MODEL` 默认 `claude-3-5-sonnet-20241022`

> AI 供应商配置会持久化到数据库表 `ai_provider_config`。优先级：**环境变量（配置文件） > 数据库**；当环境变量为默认值时，运行时会优先采用数据库中保存的值。

### 日志

- `LOG_LEVEL` 默认 `info`
- `LOG_FORMAT` 默认 `json`（可选 `text`）
- `LOG_STDOUT_ENABLED` 默认 `true`
- `LOG_FILE_ENABLED` 默认 `true`
- `LOG_FILE_PATH` 默认 `./data/logs/app.log`
- `LOG_FILE_MAX_SIZE_MB` 默认 `20`
- `LOG_FILE_MAX_BACKUPS` 默认 `10`
- `LOG_FILE_MAX_AGE_DAYS` 默认 `7`
- `LOG_COMPRESS` 默认 `false`
- `LOG_HTTP_BODY_ENABLED` 默认 `false`
- `LOG_HTTP_BODY_MAX_BYTES` 默认 `2048`
- `LOG_REDACTION_MODE` 默认 `production_only`
- `LOG_SQL_ENABLED` 默认 `true`
- `LOG_SQL_SLOW_MS` 默认 `200`
- `LOG_AI_SUMMARY_ENABLED` 默认 `true`

## 任务管理

- `TODO.md` 已废弃，不再作为任务来源
- 任务拆解、状态流转、驳回原因统一记录在 Notion `Self-Study-Tool` 看板
- 状态流转：`未开始 -> TODO -> In-Progress -> Review -> Finish / REJECT`
