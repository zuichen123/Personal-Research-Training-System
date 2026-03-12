# Common Widgets

Reusable UI components and design tokens for the application.

## Design Tokens

`app_theme.dart` provides:
- **Colors**: primary, error, success
- **Spacing**: xs (4), s (8), m (16), l (24), xl (32)
- **Radius**: s (4), m (8), l (16)

## Usage

```dart
import 'package:flutter_client/widgets/common/app_theme.dart';

Container(
  padding: EdgeInsets.all(AppSpacing.m),
  decoration: BoxDecoration(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(AppRadius.m),
  ),
)
```
