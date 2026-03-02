# Self-Study-Tool

基于 Go 的智能化自学管理器后端框架，现已接入轻量 SQL：`SQLite`。

## 已实现能力

- 题目管理（增删改查）
- 错题本管理
- AI 自动出题（Mock Provider，可替换真实 LLM）
- 做题并 AI 批阅（错题自动沉淀）
- 学习资料管理（图片/文本/PDF 等文件上传、存储、下载）
- 跨平台客户端骨架（Fyne：桌面 + Android）

## 存储方案

- 数据库：SQLite（默认 `./data/self-study.db`）
- 文件：统一存储在 SQLite `BLOB` 字段
- 元数据：文件名、MIME、大小、标签、关联题目、SHA256

## 快速启动后端

```bash
go run ./cmd/server
```

默认端口：`8080`

## 跨平台客户端（桌面/安卓）

客户端位于：`apps/fyne-client`

```bash
cd apps/fyne-client
go mod tidy
go run ./cmd/client
```

更多打包说明见：[apps/fyne-client/README.md](apps/fyne-client/README.md)

## 目录结构

```text
cmd/server
apps/fyne-client
internal/bootstrap
internal/config
internal/platform
  httpserver
  storage/sqlite
internal/modules
  ai
  mistake
  practice
  question
  resource
  system
internal/shared
```

## API

- `GET /api/v1/healthz`
- `POST /api/v1/questions`
- `GET /api/v1/questions`
- `GET /api/v1/questions/{id}`
- `PUT /api/v1/questions/{id}`
- `DELETE /api/v1/questions/{id}`
- `POST /api/v1/mistakes`
- `GET /api/v1/mistakes`
- `POST /api/v1/ai/questions/generate?persist=true`
- `POST /api/v1/ai/grade`
- `POST /api/v1/practice/submit`
- `GET /api/v1/practice/attempts`
- `POST /api/v1/resources` (`multipart/form-data`, field: `file`)
- `GET /api/v1/resources`
- `GET /api/v1/resources/{id}`
- `GET /api/v1/resources/{id}/download`

## 文件上传示例

```bash
curl -X POST "http://localhost:8080/api/v1/resources" \
  -F "file=@./example.pdf" \
  -F "category=notes" \
  -F "tags=math,pdf"
```

## 环境变量

- `APP_PORT` 默认 `8080`
- `HTTP_READ_TIMEOUT` 默认 `10s`
- `HTTP_WRITE_TIMEOUT` 默认 `15s`
- `HTTP_SHUTDOWN_TIMEOUT` 默认 `10s`
- `AI_PROVIDER` 默认 `mock`
- `AI_MOCK_LATENCY` 默认 `200ms`
- `SQLITE_PATH` 默认 `./data/self-study.db`
- `UPLOAD_MAX_BYTES` 默认 `20971520`（20MB）

## 构建脚本

- 后端跨平台构建：`scripts/build-cross.ps1` / `scripts/build-cross.sh`
- 客户端构建与安卓打包：`scripts/build-client.ps1`
