/// AppConfig — centralises all environment-aware configuration.
///
/// Values are injected at build / run time via --dart-define flags, with
/// sensible local-dev fallbacks so the app works out of the box.
///
/// Usage:
///   flutter run  --dart-define=API_URL=https://api.staging.sanlam.co.za/api
///   flutter build apk --dart-define=API_URL=https://api.sanlam.co.za/api
///                     --dart-define=GOOGLE_MAPS_KEY=YOUR_PROD_KEY
///
/// For VS Code / Android Studio add a launch.json / run config with the
/// above --dart-define flags.

class AppConfig {
  AppConfig._();

  // ── API base URL ─────────────────────────────────────────────────────────────
  /// Injected via --dart-define=API_URL=...
  /// Falls back to the production server URL.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://app.sanlamallianz4u.co.ug/api',
  );

  // ── Google Maps API Key ──────────────────────────────────────────────────────
  /// Injected via --dart-define=GOOGLE_MAPS_KEY=...
  /// This value is also read by native platforms via their respective config
  /// files (AndroidManifest.xml, AppDelegate.swift, index.html).
  static const String googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: 'REPLACE_WITH_GOOGLE_MAPS_API_KEY',
  );

  // ── Sanlam Member API ────────────────────────────────────────────────────────
  /// Injected via --dart-define=SANLAM_API_URL=...
  static const String sanlamApiBase = String.fromEnvironment(
    'SANLAM_API_URL',
    defaultValue: 'https://ehosccs.net/SanlamMemberApi/api/member/',
  );

  // ── Environment helpers ──────────────────────────────────────────────────────
  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static bool get isProduction => _env == 'prod';
  static bool get isStaging => _env == 'staging';
  static bool get isDev => _env == 'dev';
}
