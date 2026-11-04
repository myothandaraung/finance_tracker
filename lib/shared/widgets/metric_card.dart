import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Dashboard / report KPI card.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.hint,
    this.color,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? hint;
  final Color? color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: isHighlighted
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.14),
                    accent.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
