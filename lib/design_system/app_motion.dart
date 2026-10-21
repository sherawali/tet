import 'package:flutter/animation.dart';

/// One motion vocabulary for the whole app.
///
/// Every animation uses a duration from this file and one of the curves
/// below, so a switch never feels different from a card.
class AppMotion {
  const AppMotion._();

  /// Press feedback and small state changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default for every animated container.
  static const Duration base = Duration(milliseconds: 200);

  /// Carousels and larger movement.
  static const Duration slow = Duration(milliseconds: 300);

  /// Screen transitions and fades.
  static const Duration page = Duration(milliseconds: 400);

  /// The curve for state changes (selected tab, active card, badge).
  static const Curve standard = Curves.easeOut;

  /// The curve for movement that travels across the screen.
  static const Curve emphasized = Curves.easeInOutCubic;

  /// The curve for something that appears.
  static const Curve enter = Curves.easeOutCubic;

  /// The curve for something that leaves.
  static const Curve exit = Curves.easeInCubic;
}
