import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Label / value row used across the detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
