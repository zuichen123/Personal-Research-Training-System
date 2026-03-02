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
   - 已修复并验证通过的 Flutter 编译/分析阻塞
2. 本次提交后，下一窗口按本文档直接继续即可。

### 关键事实
1. 后端：`go test ./...` 已通过（本窗口前已验证）。
2. 前端：`flutter analyze` 与 `flutter test` 已通过（见第 5 节修复与验证记录）。

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
   - 条件导入的文件持久化实现（已通过 base+factory 拆分修复类型可见性问题）
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

## 5. 已修复阻塞（保留原始报错与修复记录）

### 原始阻塞错误（历史记录）

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

### 修复完成状态（2026-03-03）
1. `debug_log_screen.dart` 与 `resources_screen.dart` 的 `FileSaver.saveFile` 参数已由 `ext` 改为 `fileExtension`。
2. 日志持久化类型组织已重构：
   - 新增 `file_persist_base.dart` 承载 `LogFilePersist`
   - 新增 `file_persist_factory_stub.dart` / `file_persist_factory_io.dart` 作为条件导入工厂入口
   - `file_persist_stub.dart` / `file_persist_io.dart` 仅保留具体实现类
   - `app_logger.dart` 固定依赖 `file_persist_base.dart` 类型并按平台导入 factory
3. analyze 次级清理项已处理：
   - 删除 `debug_log_screen.dart` 与 `api_service.dart` 的多余 `dart:typed_data` 导入
   - 在 `practice_screen.dart` 与 `resources_screen.dart` 的异步间隙后增加 `if (!context.mounted) return;`

### 自动化验证结果（2026-03-03）
1. `go test ./...`：通过。
2. `cd apps/flutter_client && flutter analyze`：`No issues found!`
3. `cd apps/flutter_client && flutter test`：通过。
4. 非 `io` 条件导入编译验证：
   - `flutter test --platform chrome test/widget_test.dart` 因本机缺少 Chrome 可执行文件失败（环境问题）
   - 已 fallback 执行 `flutter build web --debug`，通过。

---

## 6. 后续执行顺序（命令级）

### Step 0-3 状态（2026-03-03）
1. `git status --short`：已确认基线。
2. `go test ./...`：已通过。
3. `cd apps/flutter_client && flutter analyze`：已通过。
4. `flutter test`：已通过。
5. `flutter build web --debug`：已通过（用于补足无 Chrome 环境下的 web 编译验证）。

### Step 4: 联调验证（待执行）
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
1. 后端回归：`go test ./...` 已通过（2026-03-03）。
2. 前端静态检查：`flutter analyze` 已 `No issues found`（2026-03-03）。
3. 前端测试：`flutter test` 已通过（2026-03-03）。
4. Web 编译校验：`flutter build web --debug` 已通过（2026-03-03）。

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
1. 提交类型：修复收口（Flutter 阻塞修复 + analyze 清理 + 验证回写）。
2. 包含内容：
   - `file_saver` 参数名修复（`ext` -> `fileExtension`）
   - 条件导入类型可见性修复（`file_persist_base.dart + file_persist_factory_*`）
   - analyze 告警清理（import + async gap）
   - 测试用例同步到当前导航结构（`widget_test.dart`）
   - 自动化验证结果回写到 TODO

### 当前提交命令（本窗口执行）
1. `git add -A`
2. `git commit -m "fix(flutter): fix file_saver params and log persist conditional import typing"`
3. `git commit -m "fix(flutter): clean analyze warnings and sync widget test"`
4. `git commit -m "chore(docs): update todo with closure status and verification results"`

### 后续提交策略（下一窗口）
1. `chore:` 联调验收记录（第 8 节逐项补证）。
2. `docs:` 补充运行截图/日志路径等交付材料（如需要）。

---

## 约束确认（强制）
1. TODO 文件编码：UTF-8（避免终端乱码）。
2. 本次允许 WIP，不要求当前提交立即清零 Flutter 错误。
3. `apps/fyne-client` 继续按下线处理，不恢复。
4. TODO 为下一窗口唯一事实源，必须覆盖“已完成/未完成/阻塞/命令/验收”全链路。
