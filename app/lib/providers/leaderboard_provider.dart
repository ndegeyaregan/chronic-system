import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/lifestyle_provider.dart';
import '../providers/vitals_provider.dart';
import '../providers/medications_provider.dart';
import '../services/api_service.dart';

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? error;
  final String period; // 'weekly' | 'monthly' | 'alltime'

  const LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.period = 'weekly',
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? error,
    String? period,
    bool clearError = false,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        period: period ?? this.period,
      );
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final Ref _ref;

  LeaderboardNotifier(this._ref) : super(const LeaderboardState()) {
    fetch();
  }

  Future<void> fetch({String period = 'weekly'}) async {
    state = state.copyWith(isLoading: true, period: period, clearError: true);
    try {
      final response =
          await dio.get('/leaderboard', queryParameters: {'period': period});
      final list = (response.data as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.rank.compareTo(b.rank));
      state = state.copyWith(entries: list, isLoading: false);
    } catch (_) {
      // Fallback: compute the current user's score locally from cached data
      final entry = _computeLocalEntry();
      state = state.copyWith(
        entries: entry != null ? [entry] : [],
        isLoading: false,
        error: entry == null ? 'Leaderboard unavailable. Connect to view rankings.' : null,
      );
    }
  }

  /// Computes a local leaderboard entry for the signed-in member using data
  /// already held in other providers (fitness logs, vitals, medications, meals).
  LeaderboardEntry? _computeLocalEntry() {
    final member = _ref.read(authProvider).member;
    if (member == null) return null;

    final lifestyleState = _ref.read(lifestyleProvider);
    final vitalsState = _ref.read(vitalsProvider);
    final medsState = _ref.read(medicationsProvider);

    // ── Fitness points ────────────────────────────────────────────────────
    // Steps: 1 pt per 100 steps
    // Active minutes: 2 pts per minute
    // Calories burned: 1 pt per 10 kcal
    // Workout video completed (activityType contains video category names): 50 pts
    const videoCategories = {'cardio', 'hiit', 'strength', 'yoga', 'stretching'};

    int fitnessPoints = 0;
    int workoutPoints = 0;
    for (final log in lifestyleState.fitnessLogs) {
      if (videoCategories.contains(log.activityType.toLowerCase())) {
        workoutPoints += 50; // completed a guided workout video
      }
      fitnessPoints += ((log.steps ?? 0) ~/ 100);
      fitnessPoints += log.durationMinutes * 2;
      fitnessPoints += ((log.caloriesBurned ?? 0) ~/ 10);
    }

    // ── Vital points ──────────────────────────────────────────────────────
    // 10 pts per vital log (reward consistent tracking)
    final vitalPoints = vitalsState.vitals.length * 10;

    // ── Medication points ─────────────────────────────────────────────────
    // 15 pts per active (non-completed) medication as proxy for adherence
    final medicationPoints =
        medsState.medications.where((m) => !m.isCompleted).length * 15;

    // ── Meal points ───────────────────────────────────────────────────────
    // 5 pts per meal log
    final mealPoints = lifestyleState.mealLogs.length * 5;

    final total =
        fitnessPoints + workoutPoints + vitalPoints + medicationPoints + mealPoints;

    return LeaderboardEntry(
      memberId: member.id,
      memberName: member.fullName,
      memberNumber: member.memberNumber,
      totalPoints: total,
      fitnessPoints: fitnessPoints,
      workoutPoints: workoutPoints,
      vitalPoints: vitalPoints,
      medicationPoints: medicationPoints,
      mealPoints: mealPoints,
      rank: 1,
    );
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref);
});
