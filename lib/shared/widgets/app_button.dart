import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

/// Primary action button with an inline loading state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = AppButtonStyle.filled,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonStyle style;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    final content = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(context.l10n.translate(label)),
            ],
          );

    final child = switch (style) {
      AppButtonStyle.filled => FilledButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AppButtonStyle.outlined => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AppButtonStyle.text => TextButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
    };

    if (!expand) return child;
    return SizedBox(width: double.infinity, child: child);
  }
}

enum AppButtonStyle { filled, outlined, text }
