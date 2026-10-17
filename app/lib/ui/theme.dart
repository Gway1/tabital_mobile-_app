import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the Vault theme, matching `design/prototype.html`. The prototype is light only, so the
/// app stays light even when the phone is in dark mode. Tests pass `googleFonts: false` so nothing
/// is fetched.
ThemeData buildTheme({bool googleFonts = true}) {
  TextStyle poppins(double size, FontWeight w, [Color color = Tp.navy]) => googleFonts
      ? GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color)
      : TextStyle(fontSize: size, fontWeight: w, color: color, fontFamily: 'Poppins');
  TextStyle openSans(double size, [FontWeight w = FontWeight.w400, Color color = Tp.text]) => googleFonts
      ? GoogleFonts.openSans(fontSize: size, fontWeight: w, color: color, height: 1.45)
      : TextStyle(fontSize: size, fontWeight: w, color: color, height: 1.45);

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Tp.navy,
    onPrimary: Tp.onNavy,
    secondary: Tp.gold,
    onSecondary: Tp.navy,
    error: Tp.error,
    onError: Tp.onNavy,
    surface: Tp.surface,
    onSurface: Tp.text,
    outline: Tp.line,
  );

  // Poppins for headings and amounts (the prototype's .money), Open Sans for text
  final textTheme = TextTheme(
    displaySmall: poppins(34, FontWeight.w700), // the next-payment amount
    headlineMedium: poppins(30, FontWeight.w700), // the welcome tagline, big fees
    headlineSmall: poppins(22, FontWeight.w600), // result titles, prices
    titleLarge: poppins(18, FontWeight.w600), // app bar
    titleMedium: poppins(16, FontWeight.w600), // section headings (h3)
    titleSmall: openSans(14, FontWeight.w700, Tp.navy), // names in lists
    labelLarge: poppins(14, FontWeight.w600), // amounts in rows
    bodyLarge: openSans(15),
    bodyMedium: openSans(14),
    bodySmall: openSans(13, FontWeight.w400, Tp.muted),
    labelSmall: openSans(12, FontWeight.w700, Tp.muted),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radius));
  final buttonText = openSans(15, FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tp.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark, // dark status-bar icons on the light bar
      backgroundColor: Tp.bg,
      foregroundColor: Tp.navy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: Tp.s4,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: Tp.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tp.radiusLg),
        side: const BorderSide(color: Tp.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Tp.line, space: 1, thickness: 1),
    // Gold is only for the one main action on a screen, always with navy text
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tp.gold,
        foregroundColor: Tp.navy,
        disabledBackgroundColor: Tp.gold.withValues(alpha: .45),
        disabledForegroundColor: Tp.navy.withValues(alpha: .6),
        minimumSize: const Size(64, Tp.controlHeight),
        shape: controlShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Tp.surface,
        foregroundColor: Tp.navy2,
        minimumSize: const Size(64, Tp.controlHeight),
        side: const BorderSide(color: Tp.line, width: 1.5),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tp.navy2,
        minimumSize: const Size(48, Tp.controlHeight),
        textStyle: buttonText,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Tp.navy : Tp.surface),
      side: const BorderSide(color: Tp.lineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tp.surface,
      labelStyle: openSans(14, FontWeight.w400, Tp.muted),
      hintStyle: openSans(14, FontWeight.w400, Tp.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tp.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tp.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tp.navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Tp.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => openSans(11, FontWeight.w600, s.contains(WidgetState.selected) ? Tp.navy : Tp.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? Tp.navy : Tp.muted),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Tp.surface,
      selectedColor: Tp.navy,
      side: const BorderSide(color: Tp.line),
      shape: const StadiumBorder(),
      labelStyle: openSans(13, FontWeight.w600, Tp.navy2),
      secondaryLabelStyle: openSans(13, FontWeight.w600, Tp.onNavy),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: Tp.navy, contentTextStyle: openSans(14, FontWeight.w400, Tp.onNavy)),
  );
}
