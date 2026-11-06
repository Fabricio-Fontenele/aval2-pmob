import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF1565C0);

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
    );
  }
}
