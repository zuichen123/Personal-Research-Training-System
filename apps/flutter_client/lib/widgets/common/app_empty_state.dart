import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.m),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.l),
              AppButton(text: actionText!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
