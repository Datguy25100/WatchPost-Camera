import 'package:flutter/material.dart';

class AppColors {
  static const blue = Color(0xFF3882F6);
  static const navy = Color(0xFF13233A);
  static const muted = Color(0xFF728197);
  static const border = Color(0xFFDBE3ED);
  static const surface = Color(0xFFF8FAFC);
  static const green = Color(0xFF13A964);
  static const greenBg = Color(0xFFD9F8E7);
  static const amber = Color(0xFFB66B00);
  static const amberBg = Color(0xFFFFF0C7);
  static const danger = Color(0xFFEF4444);
  static const tint = Color(0xFFEEF4FE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    primary: AppColors.blue,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.muted,
          )),
    ),
  );
}
