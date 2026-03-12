import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == ButtonVariant.text) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(text),
      );
    }

    final isPrimary = variant == ButtonVariant.primary;
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.primary : Colors.white,
        foregroundColor: isPrimary ? Colors.white : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      ),
      child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(text),
    );
  }
}
