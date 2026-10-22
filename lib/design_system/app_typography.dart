import 'package:flutter/material.dart';

import 'app_strings.dart';

/// App typography system with bilingual Hindi (Noto Sans Devanagari) + English
/// (Outfit/Inter) support.
///
/// The three faces are bundled with the app (see `pubspec.yaml`), so the exam
/// looks exactly the same with or without an internet connection.  They are
/// variable fonts, therefore the weight is selected through the "wght" axis.
///
/// The chrome styles (titles, labels, bodies of buttons and cards) pick the
/// primary family by the app language: Hindi UI text is set in Noto Sans
/// Devanagari directly, never through a fallback, because FontVariation only
/// reaches the primary family and a Hindi heading whose weight silently drops
/// to 400 looks flat instead of premium.  An explicit FontWeight is also set
/// on every style so the weight holds even on faces without a variable axis.
class AppTypography {
  const AppTypography._();

  static const String _latin = 'Outfit';
  static const String _devanagari = 'Noto Sans Devanagari';
  static const String _ui = 'Inter';

  /// Hindi has its own word marks and matra ligatures, letter spacing breaks
  /// their joining, so it is only applied on Latin text.
  static bool get _isHi => AppStrings.isHindi;

  /// The primary family for the chrome text of the current language.
  static String get _chrome => _isHi ? _devanagari : _latin;

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

  // English / Numerics style (Outfit · Devanagari in the Hindi mode)
  static TextStyle displayLarge({Color? color}) => TextStyle(
        fontFamily: _chrome,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: _isHi ? 0 : -0.5,
        height: _isHi ? 1.3 : 1.2,
        color: color,
      );

  static TextStyle titleLarge({Color? color}) => TextStyle(
        fontFamily: _chrome,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: _isHi ? 0 : -0.2,
        height: _isHi ? 1.35 : 1.25,
        color: color,
      );

  static TextStyle titleMedium({Color? color}) => TextStyle(
        fontFamily: _chrome,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: _isHi ? 1.4 : 1.3,
        color: color,
      );

  /// A card or a list entry that carries a slightly smaller heading.
  static TextStyle titleSmall({Color? color}) => TextStyle(
        fontFamily: _chrome,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: _isHi ? 1.4 : 1.3,
        color: color,
      );

  /// The big number of a result card.
  static TextStyle displayMedium({Color? color}) => TextStyle(
        fontFamily: _chrome,
        fontFamilyFallback: _fallback,
        fontVariations: _w(700),
        fontWeight: FontWeight.w700,
        fontSize: 44,
        letterSpacing: _isHi ? 0 : -1,
        height: 1.1,
        color: color,
      );

  /// A label that belongs to a chip or a small caption.
  static TextStyle labelMedium({Color? color}) => TextStyle(
        fontFamily: _isHi ? _devanagari : _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: _isHi ? 1.4 : 1.3,
        color: color,
      );

  /// The smallest readable body text (help lines under a title).
  static TextStyle bodySmall({Color? color}) => TextStyle(
        fontFamily: _isHi ? _devanagari : _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.45,
        color: color,
      );

  /// A short Hindi or English line under a heading.
  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: _devanagari,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontWeight: FontWeight.w400,
        fontSize: 12.5,
        height: 1.45,
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
        fontFamily: _isHi ? _devanagari : _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(400),
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => TextStyle(
        fontFamily: _isHi ? _devanagari : _ui,
        fontFamilyFallback: _fallback,
        fontVariations: _w(600),
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        letterSpacing: _isHi ? 0 : 0.5,
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

  // ------------------------------------------------------------------
  // Drop-in replacements for the former `GoogleFonts.*` calls.  They use
  // the bundled faces, so the report sheet and the snack bars look the
  // same as the rest of the app and work without a connection.
  // ------------------------------------------------------------------

  static double _wght(FontWeight? weight) {
    if (weight == null) return 400;
    return weight.value.toDouble();
  }

  static TextStyle outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    double? alpha,
  }) =>
      TextStyle(
        fontFamily: _latin,
        fontFamilyFallback: _fallback,
        fontVariations: _w(_wght(fontWeight)),
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        color: _withAlpha(color, alpha),
      );

  static TextStyle notoSansDevanagari({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    double? alpha,
  }) =>
      TextStyle(
        fontFamily: _devanagari,
        fontFamilyFallback: _fallback,
        fontVariations: _w(_wght(fontWeight)),
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        color: _withAlpha(color, alpha),
      );

  /// Monospace face for the report comment field.
  static TextStyle courierPrime({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const <String>['Courier New', 'monospace'],
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );

  static Color? _withAlpha(Color? color, double? alpha) {
    if (color == null) return null;
    if (alpha == null) return color;
    return color.withValues(alpha: alpha);
  }
}
