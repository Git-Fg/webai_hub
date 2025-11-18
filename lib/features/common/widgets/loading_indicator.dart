import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 16,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = context.hubTheme;
    final indicatorColor = color ?? theme.primaryActionButtonColor!;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );
  }
}
