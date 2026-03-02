# Self-Study-Tool 合并改造交接 TODO（UTF-8）

## 1. 项目目标与范围

### 目标
1. 完成“前后端功能对齐 + 前端全中文 + 完整日志系统”合并改造收口。
2. 让下一窗口可以不重新探索，直接按步骤继续修复并联调。

### 范围
1. 包含：Go 后端（`cmd` + `internal`）与 Flutter 前端（`apps/flutter_client`）。
2. 不包含：`apps/fyne-client`（继续按下线处理，不恢复）。
3. 日志：本地闭环（后端控制台+滚动文件；前端控制台+本地缓存+导出），不做远程上报。

### 交付标准
1. TODO 作为下一窗口唯一事实源，必须覆盖已完成、阻塞、命令、验收、风险与回滚。
2. 当前提交允许 WIP 快照，不要求本提交内清零 Flutter 报错。

---

## 2. 当前分支与快照

### Git 基线
1. 当前分支：`main`
2. 最近已存在检查点提交：`5241ac3 chore: checkpoint before full alignment implementation`

### 本次快照性质
1. 这是“可续做快照”，包含：
   - 已完成的大量后端与前端改造
   - 明确记录但尚未修复的 Flutter 编译/分析阻塞
2. 本次提交后，下一窗口按本文档直接继续即可。

### 关键事实
1. 后端：`go test ./...` 已通过（本窗口前已验证）。
2. 前端：`flutter analyze` 与 `flutter test` 当前未通过（见第 5 节原始报错）。

---

## 3. 已完成改动清单（后端）

### 配置与文档
1. 已扩展后端配置：`internal/config/config.go`
   - 新增日志配置：`LOG_*`
   - 新增 AI 多 provider 配置：`AI_OPENAI_*`、`AI_GEMINI_*`、`AI_CLAUDE_*`、`AI_HTTP_TIMEOUT`、`AI_FALLBACK_TO_MOCK`
2. 已更新环境变量模板：`.env.example`
3. 已更新项目文档：`README.md`

### 日志系统
1. 新增日志底座目录：`internal/platform/observability/logx/`
2. `cmd/server/main.go` 已接入 `slog + lumberjack` 初始化与生命周期日志。
3. `internal/platform/httpserver/middleware.go` 已改为：
   - 自定义结构化请求日志
   - `X-Trace-ID` 透传
   - panic recover 结构化日志
4. `internal/platform/httpserver/router.go` 已补充：
   - 允许请求头 `X-Trace-ID`
   - 暴露响应头 `X-Trace-ID`
5. `internal/shared/httpx/response.go` 已补充错误日志输出。

### 后端接口与业务对齐
1. 错题模块补齐：
   - `GET /api/v1/mistakes/{id}`
   - `DELETE /api/v1/mistakes/{id}`
   - 对应 repository/service/handler/sqlite/memory 均已实现
2. 资源模块补齐：
   - `DELETE /api/v1/resources/{id}`
   - 对应 repository/service/handler/sqlite 已实现
3. 练习模块增强：
   - `GET /api/v1/practice/attempts?question_id=...` 过滤能力已实现
4. AI 模块增强：
   - `GET /api/v1/ai/provider` 状态接口已实现
5. 番茄钟增强：
   - `Start` 前校验“仅允许一个 running 会话”，冲突返回 `409`

### AI 多 provider
1. 已新增：
   - `internal/modules/ai/openai_client.go`
   - `internal/modules/ai/gemini_client.go`
   - `internal/modules/ai/claude_client.go`
   - `internal/modules/ai/remote_client.go`
2. `internal/bootstrap/app.go` 已实现 provider 选择与 fallback 到 mock。
3. `internal/modules/ai/client.go` 已扩展 provider 状态接口能力。

### 后端测试状态
1. `go test ./...`：通过。

---

## 4. 已完成改动清单（前端）

### 依赖与基础模块
1. 已新增依赖：`file_picker`、`file_saver`、`path_provider`、`uuid`
2. 已新增日志模块：`apps/flutter_client/lib/core/logging/*`
   - `AppLogger`
   - `LogRecord`
   - `TraceId`
   - 条件导入的文件持久化实现（当前仍有类型可见性问题，见第 5 节）
3. 已新增错误映射：`apps/flutter_client/lib/i18n/error_mapper.dart`

### 主入口与导航
1. `apps/flutter_client/lib/main.dart` 已改造：
   - 接入全局异常日志
   - 底部导航新增 `AI`、`日志` 两页
2. 已新增页面：
   - `apps/flutter_client/lib/screens/ai_screen.dart`
   - `apps/flutter_client/lib/screens/debug_log_screen.dart`

### API 层与状态层
1. `apps/flutter_client/lib/services/api_service.dart` 已重写：
   - 新增后端新接口封装
   - API 调用日志
   - `X-Trace-ID` 请求头注入
   - `ApiException` 统一错误对象
2. `apps/flutter_client/lib/providers/app_provider.dart` 已重写：
   - 补齐 CRUD 与 AI 调用
   - 状态分区管理
   - 中文错误映射接入

### 业务页面（中文化 + 功能补齐）
1. 已重写：
   - `questions_screen.dart`
   - `mistakes_screen.dart`
   - `practice_screen.dart`
   - `resources_screen.dart`
   - `plans_screen.dart`
   - `pomodoro_screen.dart`
2. 页面已由占位提示转为真实交互路径（但仍需通过 analyze/test 与联调收口）。

---

## 5. 已识别阻塞（必须含原始报错）

### 当前阻塞错误（原文）

#### A. `flutter analyze` 阻塞
```text
error - The named parameter 'ext' isn't defined - lib\screens\debug_log_screen.dart:161:7 - undefined_named_parameter
error - The named parameter 'ext' isn't defined - lib\screens\resources_screen.dart:174:9 - undefined_named_parameter
```

```text
info - The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart' - lib\screens\debug_log_screen.dart:2:8 - unnecessary_import
info - Don't use 'BuildContext's across async gaps - lib\screens\practice_screen.dart:106:7 - use_build_context_synchronously
info - Don't use 'BuildContext's across async gaps - lib\screens\resources_screen.dart:121:7 - use_build_context_synchronously
info - The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart' - lib\services\api_service.dart:2:8 - unnecessary_import
```

#### B. `flutter test` 阻塞
```text
lib/core/logging/app_logger.dart:20:9: Error: Type 'LogFilePersist' not found.
final LogFilePersist _filePersist = createLogFilePersist();
      ^^^^^^^^^^^^^^

lib/core/logging/app_logger.dart:20:9: Error: 'LogFilePersist' isn't a type.
final LogFilePersist _filePersist = createLogFilePersist();
      ^^^^^^^^^^^^^^

lib/screens/debug_log_screen.dart:161:7: Error: No named parameter with the name 'ext'.
      ext: 'log',
      ^^^

lib/screens/resources_screen.dart:174:9: Error: No named parameter with the name 'ext'.
        ext: file.filename.contains('.')
        ^^^
```

### 根因定位与明确修复方案

#### 1) `file_saver` 参数名错误
1. 当前代码误用 `ext`。
2. `file_saver 0.3.1` 正确参数是 `fileExtension`。
3. 参考本地源码（已确认）：
   - `C:\Users\62758\AppData\Local\Pub\Cache\hosted\pub.flutter-io.cn\file_saver-0.3.1\lib\file_saver.dart`

#### 2) `LogFilePersist` 类型在条件导入下不可见
1. 当前 `app_logger.dart` 通过条件导入直接引用 `file_persist_stub.dart if (dart.library.io) file_persist_io.dart`。
2. 由于类型定义放在 stub 文件，`io` 分支下该类型不可见，导致 `flutter test` 编译失败。
3. 固定修复方案（必须按此做）：
   - 新增 `file_persist_base.dart`，只放 `abstract class LogFilePersist`
   - `app_logger.dart` 只依赖：
     - `file_persist_base.dart`（类型）
     - 条件导入 `file_persist_factory_*.dart`（工厂）
   - `file_persist_stub.dart`、`file_persist_io.dart` 只实现工厂和具体类，不再承载公共类型定义

#### 3) 次级清理项
1. `unnecessary_import`
2. `use_build_context_synchronously`
3. 这些不影响核心架构，但应在 `flutter analyze` 收口时一并处理。

---

## 6. 下一窗口执行顺序（命令级）

### Step 0: 环境与现状确认
1. `git status --short`
2. `go test ./...`
3. `cd apps/flutter_client && flutter analyze`
4. `flutter test`

### Step 1: 先修编译阻塞（必须优先）
1. 修 `debug_log_screen.dart` 和 `resources_screen.dart`：
   - `ext` -> `fileExtension`
2. 重构日志持久化类型组织：
   - 新增 `file_persist_base.dart`
   - 调整 `app_logger.dart` 条件导入路径，确保 `LogFilePersist` 类型稳定可见

### Step 2: 处理 analyze 剩余告警
1. 清理不必要 import
2. 修复 async gap 上下文使用（`mounted` 判定/局部 context）

### Step 3: 回归验证
1. `flutter analyze`
2. `flutter test`
3. `go test ./...`

### Step 4: 联调验证
1. 后端：`go run ./cmd/server`
2. 前端：`flutter run`
3. 按第 8 节验收清单逐项验证

---

## 7. 接口与类型变更总表

### 新增 API
1. `GET /api/v1/mistakes/{id}`
2. `DELETE /api/v1/mistakes/{id}`
3. `DELETE /api/v1/resources/{id}`
4. `GET /api/v1/ai/provider`

### 增强 API
1. `GET /api/v1/practice/attempts?question_id=...`

### 链路头
1. 请求支持：`X-Trace-ID`
2. 响应回传：`X-Trace-ID`

### 配置扩展
1. `.env.example` 已新增：
   - `LOG_*`
   - 多 provider `AI_*`

### 前端新增模块
1. `apps/flutter_client/lib/core/logging/*`
2. `apps/flutter_client/lib/screens/ai_screen.dart`
3. `apps/flutter_client/lib/screens/debug_log_screen.dart`

---

## 8. 测试与验收清单

### 自动化
1. 后端回归：`go test ./...` 必须通过。
2. 前端静态检查：`flutter analyze` 零 error。
3. 前端测试：`flutter test` 通过。

### 联调验收
1. 前端 8 个导航页可打开：
   - 题库 / 错题 / 练习 / 资料 / 计划 / 专注 / AI / 日志
2. AI provider 状态接口可用：
   - `GET /api/v1/ai/provider`
3. 新增后端接口可用：
   - 错题详情/删除
   - 资源删除
   - 练习按题过滤
4. trace 头联动：
   - 请求和响应均带 `X-Trace-ID`
5. 日志可用性：
   - 后端日志可落盘
   - 前端日志页可查看、复制、导出、清空

---

## 9. 风险与回滚策略

### 主要风险
1. Flutter 侧插件 API 与平台差异（特别是 `file_saver`）可能导致某平台行为不一致。
2. 条件导入组织不当会反复触发类型不可见问题。
3. AI 真实 provider 在无 key 场景下需要 fallback 行为验证。

### 回滚策略
1. 代码级回滚：
   - 使用当前 WIP 快照提交作为回滚锚点
2. 功能级回退：
   - AI provider 不可用时使用 `AI_FALLBACK_TO_MOCK=true`
3. 排障策略：
   - 优先保证 `flutter analyze` 与 `flutter test` 通过，再做联调

---

## 10. 提交说明与后续提交策略

### 本次提交说明
1. 提交类型：WIP 快照。
2. 包含内容：
   - 大量已完成改造（后端对齐 + 日志底座 + 前端重构）
   - 尚未修复的 Flutter 阻塞（已在第 5 节具名记录）

### 当前提交命令（本窗口执行）
1. `git add -A`
2. `git commit -m "wip: align backend/flutter features and logging foundation with detailed handoff todo"`
3. `git show --stat -1`

### 后续提交策略（下一窗口）
1. `fix:` 提交修复 Flutter 阻塞（`ext` 参数 + 条件导入类型可见性）。
2. `fix:` 提交 analyze 次级清理（import 与 async gap）。
3. `chore/docs:` 提交联调与验收文档收口。

---

## 约束确认（强制）
1. TODO 文件编码：UTF-8（避免终端乱码）。
2. 本次允许 WIP，不要求当前提交立即清零 Flutter 错误。
3. `apps/fyne-client` 继续按下线处理，不恢复。
4. TODO 为下一窗口唯一事实源，必须覆盖“已完成/未完成/阻塞/命令/验收”全链路。
