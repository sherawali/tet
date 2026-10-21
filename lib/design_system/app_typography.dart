import 'package:flutter/material.dart';

/// App typography system with bilingual Hindi (Noto Sans Devanagari) + English
/// (Outfit/Inter) support.
///
/// The three faces are bundled with the app (see `pubspec.yaml`), so the exam
/// looks exactly the same with or without an internet connection.  They are
/// variable fonts, therefore the weight is selected through the "wght" axis.
class AppTypography {
  const AppTypography._();

  static const String _latin = 'Outfit';
  static const String _devanagari = 'Noto Sans Devanagari';
  static const String _ui = 'Inter';

  /// If a bundled face ever fails to load, the system font takes over so the
  /// text can never become invisible.
  static const List<String> _fallback = <String>[
    'Noto Sans Devanagari',
    'Nirmala UI',
    'Mangal',
    'Roboto',
    'sans-serif',
  ];

  static List<FontVariation> _w(double weight) =>
      <FontVariation>[FontVariation('wght', weight)];

  // English / Numerics style (Outfit)
  static TextStyle displayLarge({Color? color}) => TextStyle(
        fontFamily: _latin,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontSize: 28,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle titleLarge({Color? color}) => TextStyle(
        fontFamily: _latin,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontSize: 20,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle titleMedium({Color? color}) => TextStyle(
        fontFamily: _latin,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontSize: 16,
        color: color,
      );

  // Question & Reading Content Style (Bilingual Optimized)
  static TextStyle questionText({Color? color, double fontSize = 16.5}) =>
      TextStyle(
        fontFamily: _devanagari,
        fontFamilyFallback: _fallback,
        fontVariations: _w(500),
        fontSize: fontSize,
        height: 1.6,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle optionText({Color? color, double fontSize = 15.0}) =>
      TextStyle(
        fontFamily: _devanagari,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontSize: fontSize,
        height: 1.5,
        color: color,
      );

  static TextStyle passageBody({Color? color}) => TextStyle(
        fontFamily: _devanagari,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontSize: 14.5,
        height: 1.7,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontSize: 14,
        height: 1.5,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => TextStyle(
        fontFamily: _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontSize: 11.5,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle numericTimer({Color? color}) => TextStyle(
        fontFamily: _latin,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontSize: 18,
        letterSpacing: 1.0,
        color: color,
      );
}
