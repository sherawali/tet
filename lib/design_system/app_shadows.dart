import 'package:flutter/material.dart';

/// Elevation and shadow tokens
class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> darkCard = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x404F46E5),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
