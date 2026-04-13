import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/meal_log.dart';
import '../models/fitness_log.dart';
import '../models/lifestyle_partner.dart';
import '../services/api_service.dart';

class LifestyleState {
  final List<MealLog> mealLogs;
  final List<FitnessLog> fitnessLogs;
  final List<LifestylePartner> partners;
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
