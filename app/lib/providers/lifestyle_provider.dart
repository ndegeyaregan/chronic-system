import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/meal_log.dart';
import '../models/fitness_log.dart';
import '../models/lifestyle_partner.dart';
import '../services/api_service.dart';

class PsychosocialCheckin {
  final String id;
  final DateTime checkinDate;
  final int? stressLevel;
  final int? anxietyLevel;
  final String? mood;
  final DateTime createdAt;

  const PsychosocialCheckin({
    required this.id,
    required this.checkinDate,
    this.stressLevel,
    this.anxietyLevel,
    this.mood,
    required this.createdAt,
  });

  factory PsychosocialCheckin.fromJson(Map<String, dynamic> json) {
    return PsychosocialCheckin(
      id: (json['id'] ?? '').toString(),
      checkinDate: DateTime.tryParse(json['checkin_date']?.toString() ?? '') ?? DateTime.now(),
      stressLevel: (json['stress_level'] as num?)?.toInt(),
      anxietyLevel: (json['anxiety_level'] as num?)?.toInt(),
      mood: json['mood']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  int get moodNumeric {
    switch (mood) {
      case 'great': return 5;
      case 'good': return 4;
      case 'okay': return 3;
      case 'bad': return 2;
      case 'terrible': return 1;
      default: return 0;
    }
  }
}

class LifestyleState {
  final List<MealLog> mealLogs;
  final List<FitnessLog> fitnessLogs;
  final List<LifestylePartner> partners;
  final List<LeaderboardEntry> leaderboard;
  final List<PsychosocialCheckin> psychosocialHistory;
  final int? myRank;
  final int waterCups;
  final int stressLevel;
  final int anxietyLevel;
  final String? moodCheckIn;
  final bool isLoading;
  final bool isPartnersLoading;
  final String? error;
  final String? partnersError;

  const LifestyleState({
    this.mealLogs = const [],
    this.fitnessLogs = const [],
    this.partners = const [],
    this.leaderboard = const [],
    this.psychosocialHistory = const [],
    this.myRank,
    this.waterCups = 0,
    this.stressLevel = 5,
    this.anxietyLevel = 5,
    this.moodCheckIn,
    this.isLoading = false,
    this.isPartnersLoading = false,
    this.error,
    this.partnersError,
  });

  LifestyleState copyWith({
    List<MealLog>? mealLogs,
    List<FitnessLog>? fitnessLogs,
    List<LifestylePartner>? partners,
    List<LeaderboardEntry>? leaderboard,
    List<PsychosocialCheckin>? psychosocialHistory,
    int? myRank,
    int? waterCups,
    int? stressLevel,
    int? anxietyLevel,
    String? moodCheckIn,
    bool? isLoading,
    bool? isPartnersLoading,
    String? error,
    String? partnersError,
    bool clearError = false,
    bool clearPartnersError = false,
  }) =>
      LifestyleState(
        mealLogs: mealLogs ?? this.mealLogs,
        fitnessLogs: fitnessLogs ?? this.fitnessLogs,
        partners: partners ?? this.partners,
        leaderboard: leaderboard ?? this.leaderboard,
        psychosocialHistory: psychosocialHistory ?? this.psychosocialHistory,
        myRank: myRank ?? this.myRank,
        waterCups: waterCups ?? this.waterCups,
        stressLevel: stressLevel ?? this.stressLevel,
        anxietyLevel: anxietyLevel ?? this.anxietyLevel,
        moodCheckIn: moodCheckIn ?? this.moodCheckIn,
        isLoading: isLoading ?? this.isLoading,
        isPartnersLoading: isPartnersLoading ?? this.isPartnersLoading,
        error: clearError ? null : error ?? this.error,
        partnersError: clearPartnersError ? null : partnersError ?? this.partnersError,
      );

  int get todayCalories {
    final today = DateTime.now();
    return mealLogs
        .where((m) =>
            m.loggedAt.year == today.year &&
            m.loggedAt.month == today.month &&
            m.loggedAt.day == today.day)
        .fold(0, (sum, m) => sum + (m.calories ?? 0));
  }

  int get todaySteps {
    final today = DateTime.now();
    return fitnessLogs
        .where((f) =>
            f.loggedAt.year == today.year &&
            f.loggedAt.month == today.month &&
            f.loggedAt.day == today.day)
        .fold(0, (sum, f) => sum + (f.steps ?? 0));
  }

  int get todayActiveMinutes {
    final today = DateTime.now();
    return fitnessLogs
        .where((f) =>
            f.loggedAt.year == today.year &&
            f.loggedAt.month == today.month &&
            f.loggedAt.day == today.day)
        .fold(0, (sum, f) => sum + f.durationMinutes);
  }

  int get breathingCompletionCount {
    return fitnessLogs
        .where((f) => f.activityType == 'breathing_exercise')
        .length;
  }

  int get breathingCompletionsThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return fitnessLogs
        .where((f) =>
            f.activityType == 'breathing_exercise' &&
            f.loggedAt.isAfter(start))
        .length;
  }
}

class LifestyleNotifier extends StateNotifier<LifestyleState> {
  LifestyleNotifier() : super(const LifestyleState()) {
    fetchAll();
  }

  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait([
        fetchMealLogs(),
        fetchFitnessLogs(),
        fetchWater(),
        fetchLeaderboard(),
        fetchPsychosocialHistory(),
      ]);
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: extractErrorMessage(e));
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load lifestyle data.');
    }
  }

  Future<void> fetchMealLogs() async {
    try {
      final response = await dio.get('/lifestyle/meals');
      final raw = response.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);
      final logs = items
          .map((e) => MealLog.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(mealLogs: logs);
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }

  Future<void> fetchFitnessLogs() async {
    try {
      final response = await dio.get('/lifestyle/fitness');
      final raw = response.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);
      final logs = items
          .map((e) => FitnessLog.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(fitnessLogs: logs);
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }

  Future<void> fetchWater() async {
    try {
      final response = await dio.get('/lifestyle/water');
      final data = response.data;
      final cups = (data is Map ? (data['cups'] ?? 0) : 0) as int;
      state = state.copyWith(waterCups: cups);
    } on DioException catch (_) {
      // Silently ignore — water will default to 0
    }
  }

  Future<void> fetchLeaderboard({String period = 'week'}) async {
    try {
      final response = await dio.get('/lifestyle/leaderboard',
          queryParameters: {'period': period});
      final data = response.data as Map<String, dynamic>;
      final list = (data['leaderboard'] as List? ?? [])
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final myRank = data['my_rank'] as int?;
      state = state.copyWith(leaderboard: list, myRank: myRank);
    } on DioException catch (_) {
      // Silently ignore — leaderboard is optional
    }
  }

  Future<void> fetchPsychosocialHistory() async {
    try {
      final response = await dio.get('/lifestyle/psychosocial');
      final raw = response.data;
      final items = raw is List ? raw : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);
      final history = items
          .map((e) => PsychosocialCheckin.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(psychosocialHistory: history);
    } on DioException catch (_) {
      // Silently ignore
    }
  }

  Future<bool> logBreathingCompletion(int rounds, int durationSeconds) async {
    return logFitness({
      'activity_type': 'breathing_exercise',
      'duration_minutes': (durationSeconds / 60).ceil(),
      'steps': 0,
      'calories_burned': 0,
    });
  }

  Future<void> fetchPartners({PartnerType? type, String? city,
      double? userLat, double? userLng}) async {
    state = state.copyWith(isPartnersLoading: true, clearPartnersError: true);
    try {
      final response = await dio.get('/lifestyle/partners', queryParameters: {
        if (type != null) 'type': type.name,
        if (city != null) 'city': city,
      });
      final raw = response.data;
      final list = raw is List ? raw : (raw['data'] as List? ?? []);
      var partners = list
          .map((e) => LifestylePartner.fromJson(e as Map<String, dynamic>))
          .toList();

      if (userLat != null && userLng != null) {
        partners.sort((a, b) {
          final da = _haversineKm(userLat, userLng,
              a.latitude ?? 9999, a.longitude ?? 9999);
          final db = _haversineKm(userLat, userLng,
              b.latitude ?? 9999, b.longitude ?? 9999);
          return da.compareTo(db);
        });
      }

      state = state.copyWith(partners: partners, isPartnersLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isPartnersLoading: false,
        partnersError: extractErrorMessage(e),
      );
    } catch (e) {
      state = state.copyWith(
        isPartnersLoading: false,
        partnersError: 'Failed to load partners. Please try again.',
      );
    }
  }

  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<List<PartnerVideo>> fetchPartnerVideos(String partnerId) async {
    try {
      final response =
          await dio.get('/lifestyle/partners/$partnerId/videos');
      return (response.data as List)
          .map((e) => PartnerVideo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  Future<bool> logMeal(Map<String, dynamic> data, {String? photoPath}) async {
    try {
      final Response response;
      if (photoPath != null) {
        final formData = FormData.fromMap({
          ...data,
          'photo': await MultipartFile.fromFile(photoPath),
        });
        response = await dio.post(
          '/lifestyle/meals',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
      } else {
        response = await dio.post('/lifestyle/meals', data: data);
      }
      final log = MealLog.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = state.copyWith(mealLogs: [log, ...state.mealLogs]);
      // Refresh leaderboard after logging meal to show updated data
      await fetchLeaderboard();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> logFitness(Map<String, dynamic> data) async {
    try {
      final response = await dio.post('/lifestyle/fitness', data: data);
      final log = FitnessLog.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = state.copyWith(fitnessLogs: [log, ...state.fitnessLogs]);
      // Refresh leaderboard after logging fitness to show updated data
      await fetchLeaderboard();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
      return false;
    }
  }

  Future<void> updatePsychosocial({
    int? stress,
    int? anxiety,
    String? mood,
  }) async {
    state = state.copyWith(
      stressLevel: stress,
      anxietyLevel: anxiety,
      moodCheckIn: mood,
    );
    try {
      await dio.post('/lifestyle/psychosocial', data: {
        if (stress != null) 'stress_level': stress,
        if (anxiety != null) 'anxiety_level': anxiety,
        if (mood != null) 'mood': mood,
      });
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }

  void addWaterCup() {
    state = state.copyWith(waterCups: state.waterCups + 1);
    _persistWater(state.waterCups);
  }

  void removeWaterCup() {
    if (state.waterCups > 0) {
      state = state.copyWith(waterCups: state.waterCups - 1);
      _persistWater(state.waterCups);
    }
  }

  Future<void> _persistWater(int cups) async {
    try {
      await dio.post('/lifestyle/water', data: {'cups': cups});
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }

  Future<bool> sendMoodAlert(String mood, String? notes) async {
    try {
      await dio.post('/alerts/mood', data: {
        'mood': mood,
        if (notes != null) 'notes': notes,
      });
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<bool> sendPsychosocialAlert(
      int stressLevel, int anxietyLevel) async {
    try {
      await dio.post('/alerts/psychosocial', data: {
        'stress_level': stressLevel,
        'anxiety_level': anxietyLevel,
      });
      return true;
    } on DioException catch (_) {
      return false;
    }
  }
}

final lifestyleProvider =
    StateNotifierProvider<LifestyleNotifier, LifestyleState>((ref) {
  return LifestyleNotifier();
});

class LeaderboardEntry {
  final int rank;
  final String memberId;
  final String name;
  final int totalSteps;
  final int totalMinutes;
  final int totalCalories;
  final int activityCount;
  final int mealCount;
  final int waterCups;
  final int workoutCount;
  final int totalPoints;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.memberId,
    required this.name,
    required this.totalSteps,
    required this.totalMinutes,
    required this.totalCalories,
    required this.activityCount,
    required this.mealCount,
    required this.waterCups,
    required this.workoutCount,
    required this.totalPoints,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num).toInt(),
        memberId: (json['member_id'] ?? '').toString(),
        name: (json['name'] ?? 'Member').toString(),
        totalSteps: (json['total_steps'] as num? ?? 0).toInt(),
        totalMinutes: (json['total_minutes'] as num? ?? 0).toInt(),
        totalCalories: (json['total_calories'] as num? ?? 0).toInt(),
        activityCount: (json['activity_count'] as num? ?? 0).toInt(),
        mealCount: (json['meal_count'] as num? ?? 0).toInt(),
        waterCups: (json['water_cups'] as num? ?? 0).toInt(),
        workoutCount: (json['workout_count'] as num? ?? 0).toInt(),
        totalPoints: (json['total_points'] as num? ?? 0).toInt(),
        isCurrentUser: json['is_current_user'] == true,
      );
}
