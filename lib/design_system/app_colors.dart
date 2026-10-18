import 'package:flutter/material.dart';

/// Authentic Examination Booklet Color Palette
/// Completely custom - zero generic Material demo colors.
class AppColors {
  // Brand & Examination Authority
  static const Color primary = Color(0xFF0F172A); // Deep Slate Navy (Real Exam Board)
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color primaryDark = Color(0xFF020617); // Obsidian Midnight
  static const Color primarySubtle = Color(0xFFF1F5F9); // Crisp Slate 100

  // Gold Seal & Prestige (State Exam Seal, Hit Rate Star)
  static const Color sealGold = Color(0xFFB45309); // Brass Amber 700
  static const Color sealGoldLight = Color(0xFFD97706); // Amber 600
  static const Color sealGoldSubtle = Color(0xFFFEF3C7); // Warm Amber 100

  static const Color accent = Color(0xFF0284C7); // Board Blue 600
  static const Color violet = Color(0xFF6D28D9); // Deep Royal Purple (Model indicator)

  // Status & Assessment (Official OMR style)
  static const Color success = Color(0xFF15803D); // Forest Green 700 (Attempted / Correct)
  static const Color correctGreen = Color(0xFF15803D); // Alias for clean exam status
  static const Color successDark = Color(0xFF14532D);
  static const Color successSubtle = Color(0xFFDCFCE7);

  static const Color danger = Color(0xFFDC2626); // Crimson 600 (Skipped / Incorrect)
  static const Color dangerDark = Color(0xFF991B1B);
  static const Color dangerSubtle = Color(0xFFFEE2E2);

  static const Color warning = Color(0xFFD97706); // Amber 600 (Flagged)
  static const Color warningDark = Color(0xFF92400E);
  static const Color warningSubtle = Color(0xFFFFFBEB);

  // Selected Option Highlight (Identical to HTML Paper: #DBEAFE & #3B82F6)
  static const Color optionSelectedBg = Color(0xFFDBEAFE);
  static const Color optionSelectedBorder = Color(0xFF2563EB);
  static const Color optionSelectedText = Color(0xFF1D4ED8);

  // Subject Section Tags
  static const Color cdp = Color(0xFF1D4ED8); // Blue (बाल विकास)
  static const Color hindi = Color(0xFFC2410C); // Deep Rust/Orange (हिन्दी)
  static const Color english = Color(0xFF0F766E); // Deep Teal (English)
  static const Color math = Color(0xFF7C3AED); // Royal Violet (गणित)
  static const Color evs = Color(0xFF15803D); // Emerald Green (पर्यावरण)
  static const Color science = Color(0xFF0284C7); // Cyan/Sky (विज्ञान)
  static const Color social = Color(0xFFB45309); // Amber Ochre (सामाजिक अध्ययन / SST)
  static const Color sanskrit = Color(0xFF9333EA); // Purple (संस्कृत)

  // Dark Theme Surfaces (Authentic Exam Desk Desk-Mat)
  static const Color darkBg = Color(0xFF0B0F19); // Rich Slate Black
  static const Color darkCard = Color(0xFF131A29); // Deep Slate Surface
  static const Color darkCardElevated = Color(0xFF1C253B); // Elevated Slate Card
  static const Color darkBorder = Color(0xFF25304B); // Slate Edge
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp White
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate Secondary
  static const Color darkTextMuted = Color(0xFF64748B); // Slate Muted

  // Light Theme Surfaces (Natural Book Paper & Crisp Ivory)
  static const Color lightBg = Color(0xFFF4F3EE); // Authentic Exam Desk Parchment
  static const Color lightCard = Color(0xFFFFFFFF); // Pure White Paper
  static const Color lightCardElevated = Color(0xFFFCFBF9); // Off-white Paper
  static const Color lightBorder = Color(0xFFCBD5E1); // Fine Book Divider
  static const Color lightTextPrimary = Color(0xFF0F172A); // Ink Navy Black
  static const Color lightTextSecondary = Color(0xFF334155); // Ink Secondary
  static const Color lightTextMuted = Color(0xFF64748B); // Ink Muted

  // Explicit Icon Tokens (Ensures no black icons in dark mode)
  static const Color darkIcon = Color(0xFFF8FAFC);
  static const Color darkIconMuted = Color(0xFF94A3B8);
  static const Color lightIcon = Color(0xFF0F172A);
  static const Color lightIconMuted = Color(0xFF64748B);

  // Physical Exam Print Colors
  static const Color printBlack = Color(0xFF111111); // True Printing Ink
  static const Color paperIvory = Color(0xFFFAF8F5); // Warm Book Page
  static const Color deskGray = Color(0xFF475569); // Desk Surface Gray
}
