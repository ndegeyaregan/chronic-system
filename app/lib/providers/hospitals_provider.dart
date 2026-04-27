import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/hospital.dart';
import '../services/api_service.dart';

class HospitalsState {
  final List<Hospital> hospitals;
  final bool isLoading;
  final String? error;

  const HospitalsState({
    this.hospitals = const [],
    this.isLoading = false,
    this.error,
  });

  HospitalsState copyWith({
    List<Hospital>? hospitals,
    bool? isLoading,
    String? error,
  }) =>
      HospitalsState(
        hospitals: hospitals ?? this.hospitals,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class HospitalsNotifier extends StateNotifier<HospitalsState> {
  HospitalsNotifier() : super(const HospitalsState()) {
    fetchHospitals();
  }

  Future<void> fetchHospitals({String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['name'] = search;

      final resp = await dio.get('/hospitals', queryParameters: params);
      final list = (resp.data as List)
          .map((j) => Hospital.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(hospitals: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load hospitals',
      );
    }
  }
}

final hospitalsProvider =
    StateNotifierProvider<HospitalsNotifier, HospitalsState>((ref) {
  return HospitalsNotifier();
});
