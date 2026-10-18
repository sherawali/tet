import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography system with bilingual Hindi (Noto Sans Devanagari) + English (Outfit/Inter) support
class AppTypography {
  // English / Numerics style (Outfit)
  static TextStyle displayLarge({Color? color}) => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle titleLarge({Color? color}) => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle titleMedium({Color? color}) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Question & Reading Content Style (Bilingual Optimized)
  static TextStyle questionText({Color? color, double fontSize = 16.5}) =>
      GoogleFonts.notoSansDevanagari(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.6,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle optionText({Color? color, double fontSize = 15.0}) =>
      GoogleFonts.notoSansDevanagari(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle passageBody({Color? color}) =>
      GoogleFonts.notoSansDevanagari(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.7,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle numericTimer({Color? color}) => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color,
      );
}
