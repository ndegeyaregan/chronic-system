import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';
import 'lifestyle_provider.dart';

/// Automatic step / activity tracking.
///
/// Primary data source: **Health Connect** (Android) or **HealthKit** (iOS).
/// These OS-level stores are continuously updated by the phone — even when
/// the app is closed, the screen is off, or the device just rebooted — so
/// `dailySteps` always reflects the true count when the user opens the app.
/// They also internally filter out passive motion in vehicles (the platform
/// pedometer rejects motion that doesn't match a walking/running gait),
/// which is why a bus ride doesn't inflate step totals.
///
/// Fallback data source: the live `pedometer` plugin — used only when the
/// platform health store is unavailable (e.g. Health Connect not installed
/// or permission denied), so we still get *something* while the app runs.
///
/// Distance and active energy come straight from the platform when
/// available; we only fall back to a stride/calorie estimate from the raw
/// step count when no health record is present.
class StepTrackingState {
  final int dailySteps;
  final int walkingSteps;
  final int runningSteps;
  final double walkingDistanceKm;
  final double runningDistanceKm;
  final double? activeCalories;
  final bool available;
  final bool healthConnected;

  const StepTrackingState({
    this.dailySteps = 0,
    this.walkingSteps = 0,
    this.runningSteps = 0,
    this.walkingDistanceKm = 0,
    this.runningDistanceKm = 0,
    this.activeCalories,
    this.available = false,
    this.healthConnected = false,
  });

  /// Total distance for the day, in km.
  double get distanceKm {
    final fromHealth = walkingDistanceKm + runningDistanceKm;
    if (fromHealth > 0) return fromHealth;
    // Fallback estimate when no distance record exists — average stride 0.762 m.
    return dailySteps * 0.000762;
  }

  /// Active calories burned for the day. Uses health-store value when
  /// available, otherwise a rough estimate (~0.04 kcal / step).
  int get caloriesBurned {
    final fromHealth = activeCalories;
    if (fromHealth != null && fromHealth > 0) return fromHealth.round();
    return (dailySteps * 0.04).round();
  }

  StepTrackingState copyWith({
    int? dailySteps,
    int? walkingSteps,
    int? runningSteps,
    double? walkingDistanceKm,
    double? runningDistanceKm,
    double? activeCalories,
    bool? available,
    bool? healthConnected,
  }) =>
      StepTrackingState(
        dailySteps: dailySteps ?? this.dailySteps,
        walkingSteps: walkingSteps ?? this.walkingSteps,
        runningSteps: runningSteps ?? this.runningSteps,
        walkingDistanceKm: walkingDistanceKm ?? this.walkingDistanceKm,
        runningDistanceKm: runningDistanceKm ?? this.runningDistanceKm,
        activeCalories: activeCalories ?? this.activeCalories,
        available: available ?? this.available,
        healthConnected: healthConnected ?? this.healthConnected,
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

  /// While the app is foregrounded, re-poll the health store at this cadence
  /// so the visible counter stays close to live.
  static const _foregroundRefresh = Duration(minutes: 2);

  StreamSubscription<StepCount>? _pedometerSub;
  Timer? _midnightTimer;
  Timer? _refreshTimer;
  Health? _health;
  bool _healthAuthorized = false;

  /// Health data types we read from the OS health store.
  static const _healthTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  Future<void> _init() async {
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      await _flushUnsyncedFromPrefs();
    } catch (e) {
      debugPrint('StepTracking flush error: $e');
    }
    await _initHealth();
    if (!_healthAuthorized) {
      _startPedometerFallback();
    } else {
      await _refreshFromHealth();
      _refreshTimer =
          Timer.periodic(_foregroundRefresh, (_) => _refreshFromHealth());
    }
    _scheduleMidnightReset();
  }

  Future<void> _initHealth() async {
    try {
      _health = Health();
      await _health!.configure();
      // Some devices (older Androids without Health Connect) will throw here
      // — treat as unavailable and fall back to the pedometer.
      final hasPerm =
          await _health!.hasPermissions(_healthTypes) ?? false;
      if (hasPerm) {
        _healthAuthorized = true;
        return;
      }
      final granted = await _health!.requestAuthorization(
        _healthTypes,
        permissions: List<HealthDataAccess>.filled(
          _healthTypes.length,
          HealthDataAccess.READ,
        ),
      );
      _healthAuthorized = granted;
    } catch (e) {
      debugPrint('Health store unavailable: $e');
      _healthAuthorized = false;
    }
  }

  void _startPedometerFallback() {
    try {
      _pedometerSub = Pedometer.stepCountStream.listen(
        _onPedometerEvent,
        onError: (e) => debugPrint('StepTracking pedometer error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('StepTracking pedometer unavailable: $e');
    }
  }

  Future<void> _onPedometerEvent(StepCount event) async {
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
    await prefs.setString(_keyLastCountDate, todayStr);
    await prefs.setInt(_keyLastCount, daily);
  }

  Future<void> _refreshFromHealth() async {
    if (_health == null || !_healthAuthorized) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health!.getTotalStepsInInterval(start, now) ?? 0;

      double activeCalories = 0;
      double walkingDistance = 0;
      double runningDistance = 0;
      int runningSteps = 0;

      final data = await _health!.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: const [
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.WORKOUT,
        ],
      );

      for (final point in data) {
        final v = point.value;
        switch (point.type) {
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            if (v is NumericHealthValue) {
              activeCalories += v.numericValue.toDouble();
            }
            break;
          case HealthDataType.DISTANCE_DELTA:
            if (v is NumericHealthValue) {
              walkingDistance += v.numericValue.toDouble();
            }
            break;
          case HealthDataType.WORKOUT:
            if (v is WorkoutHealthValue) {
              final meters = (v.totalDistance ?? 0).toDouble();
              final wkSteps = (v.totalSteps ?? 0);
              final isRunning =
                  v.workoutActivityType == HealthWorkoutActivityType.RUNNING ||
                      v.workoutActivityType ==
                          HealthWorkoutActivityType.RUNNING_TREADMILL;
              if (isRunning) {
                runningDistance += meters;
                runningSteps += wkSteps;
                // Avoid double-counting running distance inside total walking
                walkingDistance =
                    (walkingDistance - meters).clamp(0, double.infinity);
              }
            }
            break;
          default:
            break;
        }
      }

      final walkingSteps = (steps - runningSteps).clamp(0, steps);

      if (mounted) {
        state = state.copyWith(
          dailySteps: steps,
          walkingSteps: walkingSteps,
          runningSteps: runningSteps,
          walkingDistanceKm: walkingDistance / 1000.0,
          runningDistanceKm: runningDistance / 1000.0,
          activeCalories: activeCalories > 0 ? activeCalories : null,
          available: true,
          healthConnected: true,
        );
      }

      // Persist for crash recovery / midnight sync.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastCountDate, _todayString());
      await prefs.setInt(_keyLastCount, steps);

      // Sync to backend opportunistically.
      await _syncTodayIfPossible();
    } catch (e) {
      debugPrint('Health refresh failed: $e');
    }
  }

  /// On app pause/detach, flush today's count to the backend so the user
  /// doesn't lose progress if they don't open the app again before midnight.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      if (_healthAuthorized) _refreshFromHealth();
    } else if (lifecycleState == AppLifecycleState.paused ||
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
      final calories = state.activeCalories?.round() ??
          (steps * 0.04).round();
      return await _ref.read(lifestyleProvider.notifier).logFitness({
        'activity_type': 'auto_steps',
        'duration_minutes': (steps / 100).round().clamp(1, 1440),
        'steps': steps,
        'calories_burned': calories,
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
        state = state.copyWith(
          dailySteps: 0,
          walkingSteps: 0,
          runningSteps: 0,
          walkingDistanceKm: 0,
          runningDistanceKm: 0,
          activeCalories: null,
        );
      }
      _scheduleMidnightReset();
      if (_healthAuthorized) _refreshFromHealth();
    });
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pedometerSub?.cancel();
    _midnightTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final stepTrackingProvider =
    StateNotifierProvider<StepTrackingNotifier, StepTrackingState>(
  (ref) => StepTrackingNotifier(ref),
);
