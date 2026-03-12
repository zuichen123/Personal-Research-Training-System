import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum CardPadding { none, small, medium, large }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = CardPadding.medium,
  });

  final Widget child;
  final CardPadding padding;

  double get _paddingValue {
    switch (padding) {
      case CardPadding.none:
        return 0;
      case CardPadding.small:
        return AppSpacing.s;
      case CardPadding.medium:
        return AppSpacing.m;
      case CardPadding.large:
        return AppSpacing.l;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Padding(
        padding: EdgeInsets.all(_paddingValue),
        child: child,
      ),
    );
  }
}
