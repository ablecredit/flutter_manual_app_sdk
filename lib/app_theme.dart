import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const gray100 = Color(0xFFF5F5F5);
  static const gray200 = Color(0xFFE0E0E0);
  static const gray400 = Color(0xFFBDBDBD);
  static const gray600 = Color(0xFF757575);
  static const gray800 = Color(0xFF424242);
  static const navGreen = Color(0xFF2E7D32);
  static const navGreenSurface = Color(0xFFE8F5E9);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.black,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.black,
          outline: AppColors.gray200,
        ),
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.black,
          unselectedItemColor: AppColors.gray600,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.gray200,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: AppColors.gray200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: AppColors.gray200),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.black, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          labelStyle: const TextStyle(color: AppColors.gray600, fontSize: 13),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.black,
            side: const BorderSide(color: AppColors.black),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.gray100,
          labelStyle: const TextStyle(fontSize: 12, color: AppColors.black),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.gray200),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.black : AppColors.gray400),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.gray800 : AppColors.gray200),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.black),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.black),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.gray600),
          labelSmall: TextStyle(fontSize: 11, color: AppColors.gray600, letterSpacing: 0.8),
        ),
      );
}
