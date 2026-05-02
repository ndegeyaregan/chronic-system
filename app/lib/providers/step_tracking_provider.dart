import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';
import 'lifestyle_provider.dart';

/// Tracks the device pedometer and **automatically** persists each day's
/// total step count to the backend (`/lifestyle/fitness`) so that the
/// member's history reflects passive activity without requiring a manual
/// log entry.
///
/// SharedPreferences keys:
///   step_baseline_date   — ISO date for the current baseline (yyyy-MM-dd)
///   step_baseline_value  — pedometer reading at the start of that day
///   step_last_count_date — date of the last in-memory `dailySteps` snapshot
///   step_last_count      — latest `dailySteps` snapshot (for crash recovery)
///   step_synced_date     — date of the last successful backend push
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

class StepTrackingNotifier extends StateNotifier<StepTrackingState>
    with WidgetsBindingObserver {
  StepTrackingNotifier(this._ref) : super(const StepTrackingState()) {
    _init();
  }

  final Ref _ref;

  static const _keyDate = 'step_baseline_date';
  static const _keyValue = 'step_baseline_value';
  static const _keyLastCount = 'step_last_count';
  static const _keyLastCountDate = 'step_last_count_date';
  static const _keySyncedDate = 'step_synced_date';

  /// Only push to backend when at least this many steps have accumulated for
  /// the day. Avoids creating empty/near-empty fitness logs from brief
  /// background sensor noise.
  static const _minStepsToSync = 100;

  StreamSubscription<StepCount>? _sub;
  Timer? _midnightTimer;

  Future<void> _init() async {
    if (kIsWeb) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      // Catch up on any unsynced previous-day total before resuming today.
      await _flushUnsyncedFromPrefs();
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
      baseline = prefs.getInt(_keyValue) ?? totalSteps;
    } else {
      baseline = totalSteps;
      await prefs.setString(_keyDate, todayStr);
      await prefs.setInt(_keyValue, baseline);
    }

    final daily = (totalSteps - baseline).clamp(0, 999999);
    if (mounted) {
      state = state.copyWith(dailySteps: daily, available: true);
    }
    // Persist a snapshot so a previous day can still be synced after a
    // restart that misses the midnight reset (e.g. phone was off overnight).
    await prefs.setString(_keyLastCountDate, todayStr);
    await prefs.setInt(_keyLastCount, daily);
  }

  /// On app pause/detach, flush today's count to the backend so the user
  /// doesn't lose progress if they don't open the app again before midnight.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _syncTodayIfPossible();
    }
  }

  Future<void> _syncTodayIfPossible() async {
    final today = _todayString();
    final prefs = await SharedPreferences.getInstance();
    final syncedDate = prefs.getString(_keySyncedDate);
    final steps = state.dailySteps;
    if (syncedDate == today) return; // already synced today
    if (steps < _minStepsToSync) return;
    final ok = await _pushDailySteps(steps);
    if (ok) await prefs.setString(_keySyncedDate, today);
  }

  Future<void> _flushUnsyncedFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyLastCountDate);
    final lastCount = prefs.getInt(_keyLastCount) ?? 0;
    final syncedDate = prefs.getString(_keySyncedDate);
    final today = _todayString();
    if (lastDate != null &&
        lastDate != today &&
        lastDate != syncedDate &&
        lastCount >= _minStepsToSync) {
      final ok = await _pushDailySteps(lastCount);
      if (ok) await prefs.setString(_keySyncedDate, lastDate);
    }
  }

  Future<bool> _pushDailySteps(int steps) async {
    if (steps <= 0) return false;
    // Skip silently when not authenticated — wait until next opportunity.
    final member = _ref.read(authProvider).member;
    if (member == null) return false;
    try {
      return await _ref.read(lifestyleProvider.notifier).logFitness({
        'activity_type': 'auto_steps',
        'duration_minutes': (steps / 100).round().clamp(1, 1440),
        'steps': steps,
        'calories_burned': (steps * 0.04).round(),
      });
    } catch (e) {
      debugPrint('Auto step sync failed: $e');
      return false;
    }
  }

  /// Schedule a reset when the clock rolls past midnight.
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () async {
      // Final sync of the day that's ending.
      final prefs = await SharedPreferences.getInstance();
      final endingDate = prefs.getString(_keyLastCountDate) ??
          prefs.getString(_keyDate);
      final endingCount = state.dailySteps;
      final syncedDate = prefs.getString(_keySyncedDate);
      if (endingDate != null &&
          endingDate != syncedDate &&
          endingCount >= _minStepsToSync) {
        final ok = await _pushDailySteps(endingCount);
        if (ok) await prefs.setString(_keySyncedDate, endingDate);
      }
      // Reset baseline for the new day.
      await prefs.remove(_keyDate);
      await prefs.remove(_keyValue);
      await prefs.remove(_keyLastCount);
      await prefs.remove(_keyLastCountDate);
      if (mounted) {
        state = state.copyWith(dailySteps: 0);
      }
      _scheduleMidnightReset();
    });
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}

final stepTrackingProvider =
    StateNotifierProvider<StepTrackingNotifier, StepTrackingState>(
  (ref) => StepTrackingNotifier(ref),
);
