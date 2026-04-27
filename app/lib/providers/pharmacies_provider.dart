import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/pharmacy.dart';
import '../services/api_service.dart';

class PharmaciesState {
  final List<Pharmacy> pharmacies;
  final bool isLoading;
  final String? error;

  const PharmaciesState({
    this.pharmacies = const [],
    this.isLoading = false,
    this.error,
  });

  PharmaciesState copyWith({
    List<Pharmacy>? pharmacies,
    bool? isLoading,
    String? error,
  }) =>
      PharmaciesState(
        pharmacies: pharmacies ?? this.pharmacies,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class PharmaciesNotifier extends StateNotifier<PharmaciesState> {
  PharmaciesNotifier() : super(const PharmaciesState()) {
    fetchPharmacies();
  }

  Future<void> fetchPharmacies({String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['name'] = search;

      final resp = await dio.get('/pharmacies', queryParameters: params);
      final list = (resp.data as List)
          .map((j) => Pharmacy.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(pharmacies: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load pharmacies',
      );
    }
  }
}

final pharmaciesProvider =
    StateNotifierProvider<PharmaciesNotifier, PharmaciesState>((ref) {
  return PharmaciesNotifier();
});
