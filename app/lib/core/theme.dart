import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: Brightness.light,
      primary: kPrimary,
      secondary: kAccent,
      surface: kSurface,
      error: kError,
    ),
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    cardTheme: CardTheme(
      color: kCardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorder, width: 1),
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
      hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
      labelStyle: const TextStyle(color: kSubtext),
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

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kPrimary,
      unselectedItemColor: kSubtext,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: kBg,
      selectedColor: Color(0x1A003DA5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusFull)),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),

    dividerTheme: const DividerThemeData(
      color: kBorder,
      thickness: 1,
      space: 1,
    ),

    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusXl)),
      elevation: 0,
      backgroundColor: Colors.white,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: kText,
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

    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 24),
      headlineSmall: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 20),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: kText, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: kText, fontSize: 16),
      bodyMedium: TextStyle(color: kText, fontSize: 14),
      bodySmall: TextStyle(color: kSubtext, fontSize: 12),
      labelLarge: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 14),
    ),
  );
}