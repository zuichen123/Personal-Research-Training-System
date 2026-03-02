# Self-Study-Tool

基于 Go 的智能化自学管理器，后端使用内嵌式 SQLite（单二进制开箱即用）并支持 Flutter 客户端。

架构设计文档见：[架构.md](./架构.md)

## 已实现能力

- 计划管理：月目标、月计划、日目标、日计划、当前阶段
- 学习与题库：题目管理、错题本、练习记录
- AI 能力（Mock）：学习规划、出题、联网搜题（模拟）、批阅、评估、评分
- 资料管理：图片/文本/PDF 等文件上传与下载（SQLite BLOB）
- 番茄钟：开始/结束专注会话与历史记录
- 客户端：Flutter（Windows/Linux/Android/iOS/Web 多端工程）

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
- 计划：`POST/GET/PUT/DELETE /api/v1/plans`
- 题库：`POST/GET/PUT/DELETE /api/v1/questions`
- 错题：`POST/GET /api/v1/mistakes`
- 练习：`POST /api/v1/practice/submit`，`GET /api/v1/practice/attempts`
- 资源：`POST/GET /api/v1/resources`，`GET /api/v1/resources/{id}`，`GET /api/v1/resources/{id}/download`
- 番茄钟：`POST /api/v1/pomodoro/start`，`POST /api/v1/pomodoro/{id}/end`，`GET /api/v1/pomodoro`
- AI：
  - `POST /api/v1/ai/learning`
  - `POST /api/v1/ai/questions/generate?persist=true`
  - `GET /api/v1/ai/questions/search`
  - `POST /api/v1/ai/grade`
  - `POST /api/v1/ai/evaluate`
  - `POST /api/v1/ai/score`

## 存储

- 数据库：`SQLITE_PATH`（默认 `./data/self-study.db`）
- 文件内容：`resources.data`（BLOB）

## 环境变量

- `APP_PORT` 默认 `8080`
- `HTTP_READ_TIMEOUT` 默认 `10s`
- `HTTP_WRITE_TIMEOUT` 默认 `15s`
- `HTTP_SHUTDOWN_TIMEOUT` 默认 `10s`
- `AI_PROVIDER` 默认 `mock`
- `AI_MOCK_LATENCY` 默认 `200ms`
- `SQLITE_PATH` 默认 `./data/self-study.db`
- `UPLOAD_MAX_BYTES` 默认 `20971520`（20MB）
