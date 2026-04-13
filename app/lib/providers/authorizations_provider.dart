import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/authorization_request.dart';
import '../services/api_service.dart';

class AuthorizationsState {
  final List<AuthorizationRequest> requests;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  const AuthorizationsState({
    this.requests = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  AuthorizationsState copyWith({
    List<AuthorizationRequest>? requests,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) =>
      AuthorizationsState(
        requests: requests ?? this.requests,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthorizationsNotifier extends StateNotifier<AuthorizationsState> {
  AuthorizationsNotifier() : super(const AuthorizationsState()) {
    fetchMyRequests();
  }

  Future<void> fetchMyRequests() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await dio.get('/authorizations/mine');
      final list = (resp.data as List)
          .map((j) => AuthorizationRequest.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(requests: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load authorizations',
      );
    }
  }

  Future<bool> submitRequest({
    required String requestType,
    required String providerType,
    String? providerId,
    String? providerName,
    DateTime? scheduledDate,
    String? notes,
    String? memberMedicationId,
    String? treatmentPlanId,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final resp = await dio.post('/authorizations', data: {
        'request_type': requestType,
        'provider_type': providerType,
        if (providerId != null) 'provider_id': providerId,
        if (providerName != null) 'provider_name': providerName,
        if (scheduledDate != null)
          'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (memberMedicationId != null)
          'member_medication_id': memberMedicationId,
        if (treatmentPlanId != null) 'treatment_plan_id': treatmentPlanId,
      });
      final newReq = AuthorizationRequest.fromJson(
          resp.data as Map<String, dynamic>);
      state = state.copyWith(
        requests: [newReq, ...state.requests],
        isSubmitting: false,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.response?.data?['message'] ?? 'Failed to submit request',
      );
      return false;
    }
  }

  Future<void> cancelRequest(String id) async {
    try {
      await dio.patch('/authorizations/$id/cancel');
      state = state.copyWith(
        requests: state.requests.map((r) {
          if (r.id == id) {
            return AuthorizationRequest.fromJson({
              ...r.toJsonMap(),
              'status': 'cancelled',
            });
          }
          return r;
        }).toList(),
      );
    } on DioException catch (_) {}
  }
}

final authorizationsProvider =
    StateNotifierProvider<AuthorizationsNotifier, AuthorizationsState>((ref) {
  return AuthorizationsNotifier();
});
