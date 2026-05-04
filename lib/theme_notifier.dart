import 'package:flutter/material.dart';

class ThemeState {
  final ThemeMode mode;
  final Color accentColor;

  const ThemeState({
    this.mode = ThemeMode.light,
    this.accentColor = const Color(0xFF4CAF50),
  });

  ThemeState copyWith({ThemeMode? mode, Color? accentColor}) => ThemeState(
    mode: mode ?? this.mode,
    accentColor: accentColor ?? this.accentColor,
  );
}

final themeNotifier = ValueNotifier<ThemeState>(const ThemeState());
