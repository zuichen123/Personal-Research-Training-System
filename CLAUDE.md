# CLAUDE.md - 项目协作指南

## 工作流程
1. 执行 `git status --short` 确认基线
2. 查询 Notion `Self-Study-Tool` 数据库获取任务
3. 按优先级处理：In-Progress > REJECT > TODO > 未开始
4. 查阅 API 清单页避免重复造轮：https://www.notion.so/31cba63208ec810ebdebd78d08036fe3
5. 实施后验证（后端 go test，Flutter flutter analyze）
6. 验证通过后提交（feat/fix/chore）

## 提交规则
- 每个需求一次提交
- 步骤：git add -A → git status --short → git commit -m "..."
- 禁止：git reset --hard, git checkout --, git commit --amend

## 产物策略
- 禁止提交：*.log, *.db-shm, *.db-wal, build/, dist/

## Notion 任务循环
- 优先级：In-Progress > REJECT > TODO > 未开始
- 任务拆解在 Notion 页内完成
- 每次只处理一个小步
- 完成后更新状态到 Review
- 驳回任务优先修复
- 问题写入 QUESTION，继续其他任务

## 测试闭环
- 代码测试通过后可用 Playwright MCP 测试 Web 端
- 累计 REJECT 3 次后进入 Review 等待人工验收
