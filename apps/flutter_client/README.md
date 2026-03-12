# PRTS Client

Personal Research & Training System 的 Flutter 客户端。

## 功能页

- Question Bank（题库）
- Wrong Question Book（错题本）
- Practice（做题与批阅）
- Resources（学习资料）
- Plans（计划管理）
- Focus（番茄钟）

## 运行

```bash
flutter pub get
flutter run
```

## 后端地址

默认自动按平台选择：

- Android 模拟器：`http://10.0.2.2:8080/api/v1`
- 其他平台：`http://127.0.0.1:8080/api/v1`

也支持运行时覆盖（推荐在后端端口非 `8080` 时使用）：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

请先启动后端：

```bash
go run ./cmd/server
```

## 组件库

项目包含统一的 UI 组件库，位于 `lib/widgets/common/`：

### AppButton
带加载状态的按钮组件，支持 primary/secondary/text 变体。

```dart
AppButton(
  text: '提交',
  onPressed: () async {
    // 自动显示加载状态
  },
  variant: ButtonVariant.primary,
)
```

### AppTextField
带验证和错误显示的文本输入框。

```dart
AppTextField(
  controller: controller,
  labelText: '用户名',
  validator: (value) => value?.isEmpty ?? true ? '请输入用户名' : null,
)
```

### AppCard
统一的卡片容器，支持 none/small/medium/large 内边距。

```dart
AppCard(
  padding: CardPadding.medium,
  child: Text('内容'),
)
```

### AppDialog
对话框组件。

```dart
showDialog(
  context: context,
  builder: (_) => AppDialog(
    title: '确认',
    content: Text('确定要删除吗？'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
      FilledButton(onPressed: () => Navigator.pop(context), child: Text('确定')),
    ],
  ),
);
```

### AppBottomSheet
底部弹出面板。

```dart
AppBottomSheet.show(
  context: context,
  child: Container(height: 200, child: Text('内容')),
);
```

## API 方法

主要 API 方法位于 `lib/providers/app_provider.dart` 和 `lib/services/api_service.dart`：

### 题目管理
```dart
// 获取题目列表
await provider.fetchQuestions();
final questions = provider.questions;

// 提交练习
await provider.submitPractice(questionId, answers, elapsedSeconds);
```

### AI 功能
```dart
// 获取 AI 代理列表
final agents = await apiService.getAIAgents();

// 创建会话
final session = await apiService.createAgentSession(agentId, title: '新会话');

// 发送消息
await apiService.sendSessionMessage(sessionId, content);
```

### 错题管理
```dart
// 获取错题列表
await provider.fetchMistakes();
final mistakes = provider.mistakes;
```

详细 API 文档见项目根目录 `docs/openapi.yaml`。

