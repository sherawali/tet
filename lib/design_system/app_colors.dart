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

  // ---- Additional tokens (added by the v20 design audit) ----------------
  // Bright variants, used on dark surfaces where the deep tones are too
  // quiet.
  static const Color accentBright = Color(0xFF38BDF8); // Sky 400
  static const Color accentSoft = Color(0xFFE0F2FE); // Sky 100
  static const Color violetBright = Color(0xFF8B5CF6); // Violet 500
  static const Color violetLight = Color(0xFFA78BFA); // Violet 400
  static const Color violetSoft = Color(0xFFF3E8FF); // Violet 100
  static const Color goldBright = Color(0xFFF59E0B); // Amber 500
  static const Color goldSoft = Color(0xFFFEF9C3); // Amber 100
  static const Color goldText = Color(0xFF92400E); // Amber 800

  // Soft surfaces with their readable text colour.
  static const Color successBorder = Color(0xFFBBF7D0);
  static const Color successText = Color(0xFF166534);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color dangerText = Color(0xFF991B1B);
  static const Color infoSurface = Color(0xFFEEF2FF);
  static const Color infoBorder = Color(0xFFCBD5F5);
  static const Color indigoSurface = Color(0xFF1E1B4B);
  static const Color indigoText = Color(0xFF818CF8);

  // ---- the last few tokens (paper themes and soft surfaces) -------------
  static const Color accentDark = Color(0xFF0369A1); // Sky 700
  static const Color lightSurface = Color(0xFFFAFAFA); // Neutral card
  static const Color indigoSoft = Color(0xFFE0E7FF); // Indigo 100
  static const Color indigoDeep = Color(0xFF4338CA); // Indigo 700
  static const Color tealDark = Color(0xFF1C2D37); // Deep teal chip
  static const Color skySoft = Color(0xFFEFF6FF); // Very light sky
  static const Color darkCardDeep = Color(0xFF131B2E); // Deeper card
  static const Color violetDeep = Color(0xFF1E1430); // Deep violet
  static const Color paperWhite = Color(0xFFFCFAFF); // Paper white
  static const Color successDeep = Color(0xFF064E3B); // Deep green
  static const Color dangerDeep = Color(0xFF450A0A); // Deep red
  static const Color paper2VioletDeep = Color(0xFF3B0764); // Paper 2 violet
  static const Color paper2BlueDeep = Color(0xFF0C4A6E); // Paper 2 blue
  static const Color paper2VioletSoft = Color(0xFFFAF5FF); // Paper 2 tint
  static const Color paper2BlueSoft = Color(0xFFF0F9FF); // Paper 2 tint

  // Neutral helpers for the light theme.
  static const Color grayText = Color(0xFF374151);
  static const Color grayBorder = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFE2E8F0);
}
