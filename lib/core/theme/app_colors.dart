import 'package:flutter/material.dart';

/// Palette shared by the theme and by the domain specific widgets
/// (status chips, profit indicators, charts).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0E6E64);
  static const Color primaryDark = Color(0xFF0A4F48);
  static const Color accent = Color(0xFFE07A3F);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);

  static const Color canvas = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color divider = Color(0xFFE2E5E9);

  static const Color positive = Color(0xFF1B5E20);
  static const Color negative = Color(0xFFB71C1C);
}
