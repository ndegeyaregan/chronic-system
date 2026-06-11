import 'package:flutter/material.dart';
import 'constants.dart';
import 'theme.dart';

/// Theme-aware semantic colours.
///
/// The original `kText`, `kSurface`, `kCardBg`, etc. constants in
/// `constants.dart` are baked-in light-mode values. Any widget that uses
/// them directly stays "light" even when the user picks dark mode, which
/// is what made content disappear (dark text on dark background, white
/// cards on dark scaffold, etc.).
///
/// `AppColors` exposes the same semantic slots as a `ThemeExtension`, so
/// they automatically pick the right value for the current `Brightness`.
/// Use them via the `BuildContext` extension below, e.g.
/// `context.c.text`, `context.c.surface`, `context.c.border`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color cardBg;
  final Color surfaceAlt;
  final Color text;
  final Color subtext;
  final Color textLight;
  final Color border;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.cardBg,
    required this.surfaceAlt,
    required this.text,
    required this.subtext,
    required this.textLight,
    required this.border,
  });

  static const AppColors light = AppColors(
    bg: kBg,
    surface: kSurface,
    cardBg: kCardBg,
    surfaceAlt: kSurfaceAlt,
    text: kText,
    subtext: kSubtext,
    textLight: kTextLight,
    border: kBorder,
  );

  static const AppColors dark = AppColors(
    bg: kDarkBg,
    surface: kDarkSurface,
    cardBg: kDarkCard,
    surfaceAlt: kDarkSurfaceAlt,
    text: kDarkText,
    subtext: kDarkSubtext,
    textLight: kDarkSubtext,
    border: kDarkBorder,
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? cardBg,
    Color? surfaceAlt,
    Color? text,
    Color? subtext,
    Color? textLight,
    Color? border,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        cardBg: cardBg ?? this.cardBg,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        text: text ?? this.text,
        subtext: subtext ?? this.subtext,
        textLight: textLight ?? this.textLight,
        border: border ?? this.border,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
      textLight: Color.lerp(textLight, other.textLight, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// Theme-aware semantic colours. Use instead of the hardcoded
  /// `kText` / `kSurface` / `kCardBg` / `kBg` / `kSurfaceAlt` /
  /// `kSubtext` / `kTextLight` / `kBorder` constants.
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
