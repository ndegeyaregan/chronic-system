import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether onboarding has been completed.
/// Pre-loaded from SharedPreferences in main.dart before runApp.
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);
