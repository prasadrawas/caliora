import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Provides theme-aware colors. Use `C.of(context)` everywhere
/// instead of `AppColors.cardSurface`, `AppColors.white`, etc.
class C {
  final BuildContext _context;
  C._(this._context);

  static C of(BuildContext context) => C._(context);

  bool get _isDark => Theme.of(_context).brightness == Brightness.dark;

  // Backgrounds
  Color get bg => _isDark ? AppColors.background : AppColors.lightBackground;
  Color get card => _isDark ? AppColors.cardSurface : AppColors.lightCardSurface;
  Color get secondary => _isDark ? AppColors.secondary : AppColors.lightSecondary;

  // Text
  Color get text => _isDark ? AppColors.white : AppColors.lightText;
  Color get text70 => _isDark ? AppColors.white70 : AppColors.lightText70;
  Color get text54 => _isDark ? AppColors.white54 : AppColors.lightText54;
  Color get text30 => _isDark ? AppColors.white30 : AppColors.lightText30;
  Color get text12 => _isDark ? AppColors.white12 : AppColors.lightText12;

  // Glass
  Color get glassBorder => _isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
  Color get glassWhite => _isDark ? AppColors.glassWhite : AppColors.lightGlassWhite;

  // Overlay for modals
  Color get overlay => _isDark
      ? Colors.black.withValues(alpha: 0.6)
      : Colors.black.withValues(alpha: 0.3);
}
