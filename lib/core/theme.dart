import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// التصميم: أبيض نظيف، بطاقات مريحة، لون تمييز أزرق داكن هادئ
class AppColors {
  static const primary = Color(0xFF1B3A5B);
  static const primaryLight = Color(0xFF2C5E8C);
  static const primarySoft = Color(0xFFEAF1F8);
  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const textDark = Color(0xFF1A2530);
  static const textMuted = Color(0xFF7A8699);
  static const border = Color(0xFFE8ECF1);

  static const present = Color(0xFF2E7D32);
  static const late = Color(0xFFF59E0B);
  static const absent = Color(0xFFC62828);
  static const presentSoft = Color(0xFFE8F5E9);
  static const lateSoft = Color(0xFFFFF3E0);
  static const absentSoft = Color(0xFFFFEBEE);
}

TextStyle _ar(double size, FontWeight w, Color c, {double? height}) {
  return GoogleFonts.ibmPlexSansArabic(
    fontSize: size,
    fontWeight: w,
    color: c,
    height: height,
  );
}

class AppText {
  static TextStyle title(BuildContext context) =>
      _ar(22, FontWeight.w700, AppColors.textDark);
  static TextStyle heading(double s) => _ar(s, FontWeight.w700, AppColors.textDark);
  static TextStyle bold(double s) => _ar(s, FontWeight.w600, AppColors.textDark);
  static TextStyle normal(double s, {Color c = AppColors.textDark}) =>
      _ar(s, FontWeight.w400, c);
  static TextStyle muted(double s) => _ar(s, FontWeight.w400, AppColors.textMuted);
  static TextStyle white(double s, {FontWeight w = FontWeight.w600}) =>
      _ar(s, w, Colors.white);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primary,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: AppColors.textDark),
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppText.muted(14),
      labelStyle: AppText.normal(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: _ar(16, FontWeight.w600, Colors.white),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: _ar(14, FontWeight.w600, AppColors.primary),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primarySoft,
      labelStyle: AppText.bold(13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: AppText.heading(18),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textDark,
      contentTextStyle: AppText.normal(14, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme),
  );
}