import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/vital.dart';
import '../services/api_service.dart';

class VitalsState {
  final List<Vital> vitals;
  final Vital? latest;
  final bool isLoading;
  final String? error;

  const VitalsState({
    this.vitals = const [],
    this.latest,
    this.isLoading = false,
    this.error,
  });

  VitalsState copyWith({
    List<Vital>? vitals,
    Vital? latest,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      VitalsState(
        vitals: vitals ?? this.vitals,
        latest: latest ?? this.latest,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error,
      );

  List<Vital> getLastNDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return vitals.where((v) => v.loggedAt.isAfter(cutoff)).toList();
  }
}

class VitalsNotifier extends StateNotifier<VitalsState> {
  VitalsNotifier() : super(const VitalsState()) {
    fetchVitals();
  }

  Future<void> fetchVitals() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/vitals');
      final vitals = (response.data as List)
          .map((e) => Vital.fromJson(e as Map<String, dynamic>))
          .toList();
      vitals.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      state = VitalsState(
        vitals: vitals,
        latest: vitals.isNotEmpty ? vitals.first : null,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
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
