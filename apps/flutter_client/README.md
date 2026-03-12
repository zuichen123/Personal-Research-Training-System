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
