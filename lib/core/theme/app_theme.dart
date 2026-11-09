import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemeProvider = NotifierProvider<AppThemeNotifier, ThemeMode>(
  AppThemeNotifier.new,
);

class AppThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color warning;
  final Color success;
  final Color danger;
  final Color panelBackground;
  final Color cardSurface;
  final Color subtleSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;

  Color get accentCyan => accent;
  Color get panelBg => panelBackground;
  Color get cardBg => cardSurface;
  Color get surfaceSubtle => subtleSurface;

  const AppColors({
    required this.accent,
    required this.warning,
    required this.success,
    required this.danger,
    required this.panelBackground,
    required this.cardSurface,
    required this.subtleSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
  });

  static const dark = AppColors(
    accent: Color(0xFF00E5FF),
    warning: Color(0xFFFFB300),
    success: Color(0xFF66BB6A),
    danger: Color(0xFFEF5350),
    panelBackground: Color(0xFF181B22),
    cardSurface: Color(0xFF0F172A),
    subtleSurface: Color(0xFF1E293B),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x8AFFFFFF),
    borderSubtle: Color(0x3DFFFFFF),
  );

  static const light = AppColors(
    accent: Color(0xFF00838F),
    warning: Color(0xFFEF6C00),
    success: Color(0xFF2E7D32),
    danger: Color(0xFFD32F2F),
    panelBackground: Colors.white,
    cardSurface: Color(0xFFF1F5F9),
    subtleSurface: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    borderSubtle: Color(0xFFCBD5E1),
  );

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.light ? light : dark);
  }

  @override
  AppColors copyWith({
    Color? accent,
    Color? warning,
    Color? success,
    Color? danger,
    Color? panelBackground,
    Color? cardSurface,
    Color? subtleSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      panelBackground: panelBackground ?? this.panelBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
    );
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF13161C),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        secondary: Color(0xFFFF9100),
        surface: Color(0xFF181B22),
        onSurface: Colors.white,
      ),
      cardColor: const Color(0xFF181B22),
      dividerColor: const Color(0xFF2C3240),
      fontFamily: 'Segoe UI',
      useMaterial3: true,
      extensions: const [AppColors.dark],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0097A7),
        secondary: Color(0xFFF57C00),
        surface: Colors.white,
        onSurface: Color(0xFF1E293B),
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      fontFamily: 'Segoe UI',
      useMaterial3: true,
      extensions: const [AppColors.light],
    );
  }
}
