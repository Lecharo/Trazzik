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
    );
  }
}
