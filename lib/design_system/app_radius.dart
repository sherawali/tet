import 'package:flutter/material.dart';

/// Corner radius tokens
class AppRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double base = 14.0;
  static const double lg = 18.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedBase = BorderRadius.all(Radius.circular(base));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(full));
}
