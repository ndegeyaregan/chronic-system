import 'package:flutter/material.dart';
import 'app_config.dart';

/// Base URL is resolved from the --dart-define=API_URL environment variable.
/// See lib/core/app_config.dart for details.
String get kBaseUrl => AppConfig.baseUrl;

/// Server root URL (without the /api suffix) — used to resolve media/upload
/// paths returned by the API (e.g. /uploads/prescriptions/file.pdf).
String get kServerBase =>
    kBaseUrl.endsWith('/api') ? kBaseUrl.substring(0, kBaseUrl.length - 4) : kBaseUrl;

// ── Brand colours ──────────────────────────────────────────────────────────
const Color kPrimary      = Color(0xFF003DA5);   // Sanlam deep blue
const Color kPrimaryLight = Color(0xFF1A56C4);   // lighter blue
const Color kPrimaryDark  = Color(0xFF002880);   // darker blue
const Color kAccent       = Color(0xFF00C853);   // vibrant green
const Color kAccentLight  = Color(0xFF69F0AE);
const Color kAccentAmber  = Color(0xFFFFAB00);   // amber for warnings
const Color kPurple       = Color(0xFF32ADE6);   // teal (replacing purple)

// ── Surfaces ───────────────────────────────────────────────────────────────
const Color kBg           = Color(0xFFF0F4FF);   // very light blue-tinted bg
const Color kSurface      = Color(0xFFFFFFFF);
const Color kCardBg       = Color(0xFFFFFFFF);
const Color kSurfaceAlt   = Color(0xFFF8FAFF);   // slightly tinted card

// ── Text ───────────────────────────────────────────────────────────────────
const Color kText         = Color(0xFF0F172A);
const Color kSubtext      = Color(0xFF64748B);
const Color kTextLight    = Color(0xFF94A3B8);

// ── Borders & dividers ─────────────────────────────────────────────────────
const Color kBorder       = Color(0xFFE2E8F0);
const Color kBorderFocus  = Color(0xFF003DA5);

// ── Semantic colours ───────────────────────────────────────────────────────
const Color kSuccess      = Color(0xFF10B981);
const Color kWarning      = Color(0xFFF59E0B);
const Color kError        = Color(0xFFEF4444);
const Color kInfo         = Color(0xFF3B82F6);

// ── Gradient helpers ───────────────────────────────────────────────────────
const LinearGradient kPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF003DA5), Color(0xFF1A56C4)],
);
const LinearGradient kAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF00C853), Color(0xFF00E676)],
);
const LinearGradient kWarmGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF6B35), Color(0xFFFFAB00)],
);
const LinearGradient kPurpleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF32ADE6), Color(0xFF007AFF)],
);
const LinearGradient kTealGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
);

// ── Shadows ────────────────────────────────────────────────────────────────
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x08000000), blurRadius: 6,  offset: Offset(0, 1)),
];
const List<BoxShadow> kShadowMd = [
  BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, 8)),
];
const List<BoxShadow> kShadowSm = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
];

// ── Radius ─────────────────────────────────────────────────────────────────
const double kRadiusSm  = 8;
const double kRadiusMd  = 12;
const double kRadiusLg  = 16;
const double kRadiusXl  = 24;
const double kRadiusFull = 100;

// ── Auth & storage keys ───────────────────────────────────────────────────
const String kTokenKey        = 'sanlam_auth_token';
const String kSanlamTokenKey  = 'sanlam_external_token';
const String kUserKey         = 'sanlam_user_data';
const String kSanlamPhotoKey  = 'sanlam_profile_photo_b64';

// ── Route names ───────────────────────────────────────────────────────────
const String routeOnboarding      = '/onboarding';
const String routeSplash          = '/';
const String routeLogin           = '/login';
const String routeCreatePassword  = '/create-password';
const String routeDashboard       = '/home/dashboard';
const String routeVitals          = '/home/vitals';
const String routeLogVitals       = '/home/vitals/log';
const String routeVitalsHistory   = '/home/vitals/history';
const String routeMedications     = '/home/medications';
const String routeAddMedication   = '/home/medications/add';
const String routeAppointments    = '/home/appointments';
const String routeBookAppointment = '/home/appointments/book';
const String routeLifestyle       = '/home/lifestyle';
const String routeLogMeal         = '/home/lifestyle/meal/log';
const String routeLogFitness      = '/home/lifestyle/fitness/log';
const String routePartners        = '/home/lifestyle/partners';
const String routeNotifications   = '/home/notifications';
const String routeProfile         = '/home/profile';
const String routeSettings        = '/home/profile/settings';
const String routeChangePassword  = '/home/profile/change-password';
const String routeMyProvider      = '/home/profile/my-provider';
const String routeForgotPassword  = '/forgot-password';
const String routeVerifyOtp       = '/verify-otp';
const String routeResetPassword   = '/reset-password';
const String routeRegisterSearch  = '/register';
const String routeRegisterMember  = '/register/account';
const String routeTreatment       = '/home/treatment';
const String routeLabResults       = '/home/lab-results';
const String routeFacilityFinder  = '/home/facilities';
const String routeEducation       = '/home/education';
const String routeEmergencySos    = '/emergency-sos';

// ── New feature routes ────────────────────────────────────────────────────
const String routeBenefits        = '/home/benefits';
const String routeClaims          = '/home/claims';
const String routeDependants      = '/home/dependants';
const String routeMembershipCard  = '/home/card';
const String routePreauths        = '/home/preauths';
const String routeNetwork         = '/home/network';
const String routeCycleTracker    = '/home/vitals/cycle';
const String routeReimbursement   = '/home/reimbursement';
const String routeReimbursementHistory = '/home/reimbursement/history';
const String routeCardReprintHistory   = '/home/card/reprints';
const String routePrescriptions        = '/home/prescriptions';

// ── Wellness tips ─────────────────────────────────────────────────────────
const List<String> kWellnessTips = [
  'Stay hydrated — aim for 8 glasses of water daily.',
  'A 20-minute walk can significantly lower blood sugar levels.',
  'Taking your medication at the same time each day improves adherence.',
  'Deep breathing for 5 minutes can reduce stress and lower blood pressure.',
  'Eating a balanced breakfast helps stabilise blood glucose throughout the day.',
  'Regular sleep of 7–8 hours supports your immune system and heart health.',
  'Keep a symptom diary to help your care team tailor your treatment.',
  'Small portions and frequent meals help manage blood sugar spikes.',
];