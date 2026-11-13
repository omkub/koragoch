/// ThemeData ของ app — ค่าเริ่มต้นของปุ่ม ช่องกรอก แถบแจ้งเตือน ฯลฯ มาจาก
/// ชุดสีกลาง ([AppColors]) เพื่อให้หน้าที่ยังไม่ได้กำหนดสีเองดูเป็นชุดเดียวกัน
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.card,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    error: AppColors.negative,
  );
  final control = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control));
  final buttonText = GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.w500);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.page,
    textTheme: GoogleFonts.sarabunTextTheme().apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          shape: control, textStyle: buttonText, minimumSize: const Size(64, 44)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: control,
        textStyle: buttonText,
        minimumSize: const Size(64, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        shape: control,
        textStyle: buttonText,
        minimumSize: const Size(64, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: AppColors.accent, shape: control, textStyle: buttonText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: GoogleFonts.sarabun(fontSize: 14, color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: GoogleFonts.sarabun(fontSize: 14, color: Colors.white),
      shape: control,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}
