import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

// ── Dark mode colours ─────────────────────────────────────────────────────
const Color kDarkBg        = Color(0xFF0F172A);
const Color kDarkSurface   = Color(0xFF1E293B);
const Color kDarkCard      = Color(0xFF1E293B);
const Color kDarkSurfaceAlt = Color(0xFF334155);
const Color kDarkText      = Color(0xFFF1F5F9);
const Color kDarkSubtext   = Color(0xFF94A3B8);
const Color kDarkBorder    = Color(0xFF334155);

ThemeData buildAppTheme() {
  return _buildTheme(Brightness.light);
}

ThemeData buildDarkTheme() {
  return _buildTheme(Brightness.dark);
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final bg         = isDark ? kDarkBg : kBg;
  final surface    = isDark ? kDarkSurface : kSurface;
  final cardBg     = isDark ? kDarkCard : kCardBg;
  final surfaceAlt = isDark ? kDarkSurfaceAlt : kSurfaceAlt;
  final textColor  = isDark ? kDarkText : kText;
  final subtext    = isDark ? kDarkSubtext : kSubtext;
  final border     = isDark ? kDarkBorder : kBorder;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: brightness,
      primary: kPrimary,
      secondary: kAccent,
      surface: surface,
      error: kError,
    ),
    scaffoldBackgroundColor: bg,
    fontFamily: 'Roboto',

    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? kDarkSurface : kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    cardTheme: CardTheme(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kError, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kError, width: 1.5),
      ),
      hintStyle: TextStyle(color: isDark ? kDarkSubtext : kTextLight, fontSize: 14),
      labelStyle: TextStyle(color: subtext),
      floatingLabelStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.w500),
      errorStyle: const TextStyle(color: kError, fontSize: 11),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? kDarkSurface : Colors.white,
      selectedItemColor: kPrimary,
      unselectedItemColor: subtext,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: isDark ? kDarkSurfaceAlt : kBg,
      selectedColor: const Color(0x1A003DA5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusFull)),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),

    dividerTheme: DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),

    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusXl)),
      elevation: 0,
      backgroundColor: isDark ? kDarkSurface : Colors.white,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? kDarkSurfaceAlt : kText,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
      behavior: SnackBarBehavior.floating,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kPrimary),

    sliderTheme: SliderThemeData(
      activeTrackColor: kPrimary,
      thumbColor: kPrimary,
      inactiveTrackColor: kPrimary.withValues(alpha: 0.2),
    ),

    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorColor: Colors.white,
    ),

    textTheme: TextTheme(
      headlineLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 24),
      headlineSmall: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 20),
      titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: textColor, fontSize: 16),
      bodyMedium: TextStyle(color: textColor, fontSize: 14),
      bodySmall: TextStyle(color: subtext, fontSize: 12),
      labelLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
    ),
  );
}