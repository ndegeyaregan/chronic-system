import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/vital.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class VitalsState {
  final List<Vital> vitals;
  final Vital? latest;
  final bool isLoading;
  final bool isOffline;
  final String? error;

  const VitalsState({
    this.vitals = const [],
    this.latest,
    this.isLoading = false,
    this.isOffline = false,
    this.error,
  });

  VitalsState copyWith({
    List<Vital>? vitals,
    Vital? latest,
    bool? isLoading,
    bool? isOffline,
    String? error,
    bool clearError = false,
  }) =>
      VitalsState(
        vitals: vitals ?? this.vitals,
        latest: latest ?? this.latest,
        isLoading: isLoading ?? this.isLoading,
        isOffline: isOffline ?? this.isOffline,
        error: clearError ? null : error,
      );

  List<Vital> getLastNDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return vitals.where((v) => v.loggedAt.isAfter(cutoff)).toList();
  }

  /// Most recent height recorded across all vitals (cm).
  double? get latestHeight {
    for (final v in vitals) {
      if (v.height != null) return v.height;
    }
    return null;
  }

  /// Computed BMI using the latest weight + most recent height.
  double? get latestBmi {
    final w = latest?.weight;
    final h = latestHeight;
    if (w == null || h == null || h <= 0) return null;
    final hm = h / 100.0;
    return w / (hm * hm);
  }
}

class VitalsNotifier extends StateNotifier<VitalsState> {
  VitalsNotifier() : super(const VitalsState()) {
    fetchVitals();
  }

  Future<void> fetchVitals() async {
    state = state.copyWith(isLoading: true, clearError: true, isOffline: false);
    try {
      final response = await dio.get('/vitals');
      final vitals = (response.data as List)
          .map((e) => Vital.fromJson(e as Map<String, dynamic>))
          .toList();
      vitals.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

      // Cache for offline use
      await CacheService.saveVitals(
        (response.data as List).cast<Map<String, dynamic>>(),
      );

      state = VitalsState(
        vitals: vitals,
        latest: vitals.isNotEmpty ? vitals.first : null,
      );
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      if (isNetworkError && CacheService.hasCachedVitals) {
        final cached = CacheService.loadVitals()!
            .map((e) => Vital.fromJson(e))
            .toList();
        state = state.copyWith(
          vitals: cached,
          latest: cached.isNotEmpty ? cached.first : null,
          isLoading: false,
          isOffline: true,
          error: 'Offline — showing cached data.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: extractErrorMessage(e),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load vitals. Please try again.',
      );
    }
  }

  Future<bool> logVitals(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.post('/vitals', data: data);
      final vital = Vital.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      final updated = [vital, ...state.vitals];
      state = VitalsState(vitals: updated, latest: vital);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }

}

final vitalsProvider =
    StateNotifierProvider<VitalsNotifier, VitalsState>((ref) {
  return VitalsNotifier();
});
