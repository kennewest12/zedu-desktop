import 'package:flutter/material.dart';

class AppPalette {
  final Brightness brightness;
  final Color primary;
  final Color sidebar;
  final Color accent;
  final Color onPrimary;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color borderOutline;
  final Color divider;
  final Color success;
  final Color successBg;
  final Color error;
  final Color errorBg;
  final Color primaryBg;

  /// Green dot — user is active/online.
  final Color presenceActive;

  /// Dark semi-transparent dot — user is away/offline.
  final Color presenceAway;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.sidebar,
    required this.accent,
    required this.onPrimary,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.borderOutline,
    required this.divider,
    required this.success,
    required this.successBg,
    required this.error,
    required this.errorBg,
    required this.primaryBg,
    required this.presenceActive,
    required this.presenceAway,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF6458F5),
    sidebar: Color(0xFF4848AD),
    accent: Color(0xFF5CCBBA),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCFBFF),
    textPrimary: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF0A090B),
    textHint: Color(0xFFA3A3A3),
    borderOutline: Color(0xffD0D0FD),
    divider: Color(0xffE5E7EB),
    success: Color(0xFF22C55E),
    successBg: Color(0xFFEFFFF5),
    error: Color(0xFFEF4444),
    errorBg: Color(0xFFFFF1F1),
    primaryBg: Color(0xFFF3EFFF),
    presenceActive: Color(0xFF22C55E),
    presenceAway: Color(0x661E1E1E),
  );

  /// Dark surfaces: near-black violet so the purple primary still reads as the
  /// accent. Every text token is chosen against the surfaces it is drawn on
  /// (background, sidebar, card, primaryBg, successBg, errorBg) and guarded by
  /// the WCAG AA ratios asserted in app_palette_contrast_test.dart.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF8B7CFF),
    sidebar: Color(0xFF1A1926),
    accent: Color(0xFF5CCBBA),
    onPrimary: Color(0xFF12101C),
    background: Color(0xFF121118),
    textPrimary: Color(0xFFF5F4FB),
    textSecondary: Color(0xFFCFCCE0),
    textHint: Color(0xFF9E9AB2),
    borderOutline: Color(0xFF302D40),
    divider: Color(0xFF272433),
    success: Color(0xFF5EE39B),
    successBg: Color(0xFF10301F),
    error: Color(0xFFFF8A8A),
    errorBg: Color(0xFF3B1616),
    primaryBg: Color(0xFF221D3A),
    presenceActive: Color(0xFF5EE39B),
    presenceAway: Color(0x66CFCCE0),
  );
}
