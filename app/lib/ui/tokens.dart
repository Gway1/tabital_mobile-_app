import 'package:flutter/painting.dart';

/// Vault design tokens (founder decision, 2026-09-27). Same values as the web app's
/// `tabital_front/src/styles/_tokens.scss`. Use these; never hard-code colours in screens.
abstract final class Tp {
  // Brand
  static const gold = Color(0xFFF5B700); // the one main action, always with navy text (9.8:1)
  static const goldPress = Color(0xFFE8A400);
  static const goldSoft = Color(0xFFFFF4D1);
  static const navy = Color(0xFF02163F); // frame, headings, the next-payment card
  static const navy2 = Color(0xFF0A2D73); // links, secondary actions, info
  static const navySoft = Color(0xFFE8EEFC);
  static const onNavy = Color(0xFFFFFFFF);
  static const onNavyMuted = Color(0xFFC7D2E5);

  // Neutrals
  static const text = Color(0xFF475569);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF8F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F4F9);
  static const line = Color(0xFFE2E8F0);
  static const lineStrong = Color(0xFFCFD6E3);

  // Status (always with a word and an icon, never colour alone)
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFE7F6EE);
  static const warn = Color(0xFF8A5A00);
  static const warnBg = Color(0xFFFFF4D1);
  static const error = Color(0xFFB42318);
  static const errorBg = Color(0xFFFDECEA);
  static const info = Color(0xFF0A2D73);
  static const infoBg = Color(0xFFE8EEFC);

  // Dark theme surfaces (navy-led; gold still marks only the main action)
  static const darkBg = Color(0xFF010D26);
  static const darkSurface = Color(0xFF0B1E47);
  static const darkLine = Color(0xFF1E3566);
  static const darkText = Color(0xFFC7D2E5);

  // Type sizes (sp)
  static const textSm = 13.0;
  static const textMd = 15.0;
  static const textLg = 17.0;
  static const textXl = 20.0;
  static const text2xl = 26.0;
  static const text3xl = 32.0;

  // Space (4 dp grid)
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;

  // Shape
  static const radius = 10.0; // controls
  static const radiusLg = 14.0; // cards
  static const controlHeight = 48.0; // minimum touch target
}
