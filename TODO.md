# TODO（迁移到 Linux 继续开发）

## 当前迭代（Notion：智能课程表）
- [x] Step 0：从未开始领取任务并设为 TODO
- [x] Step 0.5：拆解为可执行小步并同步到 Notion
- [x] Step 1：主界面入口 + 课程表页面骨架（年/月/日/课）
- [x] Step 2：课视图“当前课程卡片”与“开始上课”主按钮
- [x] Step 3：打通“开始上课 -> 专用上课Agent会话”启动链路
- [x] Step 4：补充“知识点总结/课后练习/掌握程度”三区块
- [x] Step 5：掌握程度记录入库（复用 plans 表，source=ai_agent）
- [x] Step 6：掌握程度写入后续复习计划（按分数生成复习计划项）
- [x] Step 7：联调与回归（flutter analyze 针对本次改动通过）

## 当前迭代（Notion：化学公式显示）
- [x] Step 1：定位题目渲染与AI输出渲染入口
- [x] Step 2：题库列表/练习会话/练习历史统一切到 `AIFormulaText`
- [x] Step 3：增强 `AIFormulaText`（下标、上标、电荷显示）
- [x] Step 4：联调与回归（flutter analyze 针对改动文件通过）
- [x] Step 5：同步 Notion 状态至 `Review`

## 0. 当前工作区快照（先确认）
- [ ] 执行：`git status --short`
- [ ] 确认当前改动文件主要是：
  - `apps/flutter_client/lib/screens/ai_screen.dart`
  - `internal/modules/ai/*.go`
  - `internal/modules/ai/*_test.go`
- [ ] 迁移到 Linux 后先 `git pull` 同步，再继续以下任务。

## 1. AI 批阅结果展示改造（最新需求）
目标：取消“AI批阅反馈标签”，新增“题目解析标签”，且默认折叠，仅手动点击展开。

- [ ] 前端定位并改造结果卡片（重点文件）：
  - `apps/flutter_client/lib/screens/question_detail_screen.dart`
  - `apps/flutter_client/lib/screens/ai_screen.dart`（若此页也展示批阅结果标签）
- [ ] 去掉原“反馈/feedback”标签页或区块。
- [ ] 新增“题目解析”展示区块，默认折叠（初始 `false`），点击后展开。
- [ ] 与后端字段对齐：优先使用 `analysis`/`explanation` 字段；若后端尚未提供，先兼容降级显示空态。

## 2. AI 作答输入方式（手写/图片/拍照/语音上传）
目标：不是语音转文字，而是直接上传音频文件作为附件。

### 2.1 Flutter 端
- [ ] `ai_screen.dart` 完整清理 `speech_to_text` 残留（import/字段/init/dispose）。
- [ ] 题卡支持：
  - [ ] 单选只能选 1 个。
  - [ ] 多选可选多个。
  - [ ] 保留“做题时问题/想法补充”文本框。
- [ ] 附件能力：
  - [ ] 上传图片（相册）
  - [ ] 拍照
  - [ ] 上传语音文件（`mp3/wav/m4a/aac/ogg/webm`）
  - [ ] 手写区（画笔/橡皮/一键清空）
  - [ ] 手写转 PNG，再转 `data:image/png;base64,...` 附件
- [ ] 提交批阅 payload：
  - [ ] `question`
  - [ ] `user_answer`
  - [ ] `attachments: [{name, source, mime_type, data_url}]`
- [ ] 清理状态：页面销毁或重置时释放 `TextEditingController`、`SignatureController`，并清空附件缓存。

### 2.2 后端（AI 模块）
- [ ] 附件校验从 image-only 扩展到 image/audio：
  - `internal/modules/ai/image_attachments.go`
- [ ] `decodeGradeRequest` 支持“仅附件无文字”场景：
  - `internal/modules/ai/handler.go`
- [ ] Provider 适配：
  - [ ] OpenAI：图片 + 音频（不支持格式时给出可解释降级）
  - [ ] Gemini：`inline_data` 兼容图片/音频
  - [ ] Claude：当前先图像直传，音频走文本降级说明（避免请求结构非法）
- [ ] Mock Provider 提示改为 media 级别（非仅 image）。

### 2.3 测试
- [ ] `internal/modules/ai/image_attachments_test.go`
  - [ ] 图片附件通过
  - [ ] 音频附件通过
  - [ ] 非法 data_url 拒绝
  - [ ] 非 image/audio mime 拒绝
- [ ] `internal/modules/ai/handler_decode_test.go`
  - [ ] 仅图片附件通过
  - [ ] 仅音频附件通过

## 3. AI 学习计划功能按设计文档补全
目标来源：`AI学习计划功能设计.md`

- [ ] 对照文档逐项核对前端交互与后端字段。
- [ ] 确保学习计划生成/优化/导入计划链路可用。
- [ ] 补齐缺失字段映射与空值兜底。
- [ ] 增加关键回归用例（至少服务层）。

## 4. AI Prompt 定制（高级设置 + 数据库存储 + 热更新）
- [ ] 设置页提供高级 Prompt 配置入口：
  - [ ] 预置 Prompt（只读）
  - [ ] 定制 Prompt（可编辑）
  - [ ] 输出格式 Prompt（可编辑）
- [ ] Prompt 构建规则落地：
  - [ ] `定制prompt/预置prompt + 输出格式说明prompt + 用户输入`
- [ ] DB 持久化 + 热更新：
  - [ ] 更新后即时生效
  - [ ] 保留预置作为兜底
- [ ] 后端接口联调：
  - [ ] `GET /api/v1/ai/prompts`
  - [ ] `PUT /api/v1/ai/prompts/{key}`
  - [ ] `POST /api/v1/ai/prompts/reload`

## 5. 历史缺陷修复计划（全仓 Bug 清理）
若尚未全部完成，继续执行：

- [ ] 严格 JSON 解码（拒绝拼接 JSON）：
  - `internal/shared/httpx/response.go`
  - 补 `internal/shared/httpx/response_test.go`
- [ ] plans 枚举校验收紧：
  - `internal/modules/plan/service.go`
  - 补 `internal/modules/plan/service_test.go`
- [ ] questions 类型校验收紧：
  - `internal/modules/question/service.go`
  - 更新 `internal/modules/question/service_test.go`

## 6. 中文编码修复（至少 main.dart）
- [ ] 修复 `apps/flutter_client/lib/main.dart` 中文乱码（导航、菜单、标题等）。
- [ ] 检查同类乱码是否影响可读性/编译（可分批修）。

## 7. 验证清单（每次阶段完成后执行）
- [ ] 后端：`go test ./...`
- [ ] Flutter：
  - [ ] `cd apps/flutter_client`
  - [ ] `flutter pub get`
  - [ ] `flutter analyze`
  - [ ] `flutter test`
- [ ] 冒烟：
  - [ ] 缺失/非法 `plan_type` -> `400`
  - [ ] 非法 question `type` -> `400`
  - [ ] 拼接 JSON body -> `400`
  - [ ] AI 题卡：图片/手写/语音附件可提交
  - [ ] AI 批阅结果：“题目解析”默认折叠，手动展开

## 8. 提交规范（按需求分提交）
- [ ] 每个需求 1 次提交：`git add -A && git status --short && git commit -m "feat|fix|chore: ..."`
- [ ] 不提交噪音文件：`*.log`、`*.db-wal`、`*.db-shm`、`build/`、`dist/`
- [ ] 回执记录：`commit hash` + `commit message` + `git status --short`
