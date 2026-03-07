# Personal Research & Training System (PRTS)

License: AGPL-3.0-or-later

基于 Go + Flutter 的智能化自学管理器。

- 后端：Go + SQLite（单二进制开箱即用）
- 客户端：Flutter（Windows/Linux/macOS/Android/iOS/Web）
- AI：`mock | openai | gemini | claude`，可配置回退到 mock
- 日志：结构化 JSON，`trace_id` 全链路，支持控制台与滚动文件

架构文档见：[架构.md](./架构.md)

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

## 核心 API

- 系统：`GET /api/v1/healthz`
- 计划：`POST/GET/GET{id}/PUT{id}/DELETE{id} /api/v1/plans`
- 题库：`POST/GET/GET{id}/PUT{id}/DELETE{id} /api/v1/questions`
- 错题：
  - `POST /api/v1/mistakes`
  - `GET /api/v1/mistakes`
  - `GET /api/v1/mistakes/{id}`
  - `DELETE /api/v1/mistakes/{id}`
- 练习：
  - `POST /api/v1/practice/submit`
  - `GET /api/v1/practice/attempts`
  - `GET /api/v1/practice/attempts?question_id=...`
  - `DELETE /api/v1/practice/attempts/{id}`
- 资源：
  - `POST /api/v1/resources`
  - `GET /api/v1/resources`
  - `GET /api/v1/resources/{id}`
  - `GET /api/v1/resources/{id}/download`
  - `DELETE /api/v1/resources/{id}`
- 番茄钟：
  - `POST /api/v1/pomodoro/start`
  - `POST /api/v1/pomodoro/{id}/end`
  - `GET /api/v1/pomodoro`
  - `DELETE /api/v1/pomodoro/{id}`
- AI：
  - `GET /api/v1/ai/provider`
  - `PUT /api/v1/ai/provider/config`
  - `POST /api/v1/ai/learning`
  - `POST /api/v1/ai/questions/generate?persist=true`
  - `GET /api/v1/ai/questions/search`
  - `POST /api/v1/ai/grade`
  - `POST /api/v1/ai/evaluate`
  - `POST /api/v1/ai/score`

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

### Profile API

- `GET /api/v1/profile`
- `PUT /api/v1/profile`
