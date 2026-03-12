# Common UI Components

Reusable widget library for consistent UI across the app.

## Components

- **AppButton**: Button with loading state and variants (primary/secondary/text)
- **AppTextField**: Text field with validation and error display
- **AppCard**: Card with padding variants (none/small/medium/large)
- **AppLoadingIndicator**: Loading indicator with optional message
- **AppErrorView**: Error display with retry button
- **AppEmptyState**: Empty state with icon/message/action
- **AppDialog**: Dialog with title, content, and action buttons
- **AppBottomSheet**: Bottom sheet with custom content

## Usage

```dart
import 'package:flutter_client/widgets/common/app_button.dart';

AppButton(
  text: 'Submit',
  onPressed: () {},
  isLoading: false,
  variant: ButtonVariant.primary,
)
```

## Design Tokens

All components use design tokens from `lib/theme/app_theme.dart`:
- Colors: primary, error, success
- Spacing: xs, s, m, l, xl
- Radius: s, m, l
