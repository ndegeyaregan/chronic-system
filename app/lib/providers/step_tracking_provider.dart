import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a daily baseline so we can compute "steps walked today"
/// from the hardware pedometer's cumulative-since-boot value.
///
/// SharedPreferences keys:
///   step_baseline_date  — ISO date string (yyyy-MM-dd)
///   step_baseline_value — the pedometer reading at the start of that day

class StepTrackingState {
  final int dailySteps;
  final bool available;

  const StepTrackingState({this.dailySteps = 0, this.available = false});

  /// Estimated distance in km (average stride ≈ 0.762 m).
  double get distanceKm => dailySteps * 0.000762;

  /// Estimated calories burned (rough average ≈ 0.04 kcal per step).
  int get caloriesBurned => (dailySteps * 0.04).round();

  StepTrackingState copyWith({int? dailySteps, bool? available}) =>
      StepTrackingState(
        dailySteps: dailySteps ?? this.dailySteps,
        available: available ?? this.available,
      );
}

class StepTrackingNotifier extends StateNotifier<StepTrackingState> {
  StepTrackingNotifier() : super(const StepTrackingState()) {
    _init();
  }

  static const _keyDate = 'step_baseline_date';
  static const _keyValue = 'step_baseline_value';

  StreamSubscription<StepCount>? _sub;
  Timer? _midnightTimer;

  Future<void> _init() async {
    if (kIsWeb) return;
    try {
      _sub = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (e) => debugPrint('StepTracking pedometer error: $e'),
        cancelOnError: false,
      );
      _scheduleMidnightReset();
    } catch (e) {
      debugPrint('StepTracking unavailable: $e');
    }
  }

  Future<void> _onStep(StepCount event) async {
    final totalSteps = event.steps;
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _todayString();

    final savedDate = prefs.getString(_keyDate);
    int baseline;

    if (savedDate == todayStr) {
      // Same day — use the saved baseline
      baseline = prefs.getInt(_keyValue) ?? totalSteps;
    } else {
      // New day (or first ever reading) — snapshot current as baseline
      baseline = totalSteps;
      await prefs.setString(_keyDate, todayStr);
      await prefs.setInt(_keyValue, baseline);
    }

    final daily = (totalSteps - baseline).clamp(0, 999999);
    if (mounted) {
      state = state.copyWith(dailySteps: daily, available: true);
    }
  }

  /// Schedule a reset when the clock rolls past midnight.
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () async {
      // Reset baseline on the new day
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDate);
      await prefs.remove(_keyValue);
      if (mounted) {
        state = state.copyWith(dailySteps: 0);
      }
      // Re-schedule for the next midnight
      _scheduleMidnightReset();
    });
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}

final stepTrackingProvider =
    StateNotifierProvider<StepTrackingNotifier, StepTrackingState>(
  (ref) => StepTrackingNotifier(),
);
