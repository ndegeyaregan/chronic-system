import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/treatment_plan.dart';
import '../services/api_service.dart';


class TreatmentPlanState {
  final List<TreatmentPlan> plans;
  final bool isLoading;
  final String? error;

  const TreatmentPlanState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  TreatmentPlanState copyWith({
    List<TreatmentPlan>? plans,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      TreatmentPlanState(
        plans: plans ?? this.plans,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class TreatmentPlanNotifier extends StateNotifier<TreatmentPlanState> {
  TreatmentPlanNotifier() : super(const TreatmentPlanState()) {
    fetchPlans();
  }

  Future<void> fetchPlans() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/treatment-plans');
      final plans = (response.data as List)
          .map((e) => TreatmentPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      state = TreatmentPlanState(plans: plans);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
    }
  }

  Future<bool> addPlan({
    String? title,
    String? description,
    double? cost,
    String? currency,
    DateTime? planDate,
    String? providerName,
    String? conditionId,
    String? conditionName,
    // document (prescription)
    String? documentPath,
    Uint8List? documentBytes,
    String? documentName,
    // photo
    Uint8List? photoBytes,
    String? photoName,
    // audio
    Uint8List? audioBytes,
    String? audioName,
    // video
    Uint8List? videoBytes,
    String? videoName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      MultipartFile? toMultipart(Uint8List? bytes, String? name) {
        if (bytes != null && name != null) {
          return MultipartFile.fromBytes(bytes, filename: name);
        }
        return null;
      }

      final formData = FormData.fromMap({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost.toString(),
        if (currency != null) 'currency': currency,
        if (planDate != null) 'plan_date': planDate.toIso8601String().split('T')[0],
        if (providerName != null) 'provider_name': providerName,
        if (conditionId != null) 'condition_id': conditionId,
        if (conditionName != null) 'condition_name': conditionName,
        if (documentBytes != null && documentName != null)
          'document': MultipartFile.fromBytes(documentBytes, filename: documentName)
        else if (documentPath != null)
          'document': await MultipartFile.fromFile(documentPath, filename: documentName),
        if (toMultipart(photoBytes, photoName) != null)
          'photo': toMultipart(photoBytes, photoName)!,
        if (toMultipart(audioBytes, audioName) != null)
          'audio': toMultipart(audioBytes, audioName)!,
        if (toMultipart(videoBytes, videoName) != null)
          'video': toMultipart(videoBytes, videoName)!,
      });
      final response = await dio.post(
        '/treatment-plans',
        data: formData,
      );
      final plan = TreatmentPlan.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = TreatmentPlanState(plans: [plan, ...state.plans]);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updatePlan(
    String id, {
    String? title,
    String? description,
    double? cost,
    String? planDate,
    String? providerName,
    String? status,
    String? documentPath,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final formData = FormData.fromMap({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost.toString(),
        if (planDate != null) 'plan_date': planDate,
        if (providerName != null) 'provider_name': providerName,
        if (status != null) 'status': status,
        if (documentPath != null)
          'document': await MultipartFile.fromFile(documentPath),
      });
      final response = await dio.put(
        '/treatment-plans/$id',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final updated = TreatmentPlan.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = state.copyWith(
        isLoading: false,
        plans: state.plans.map((p) => p.id == id ? updated : p).toList(),
      );
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

final treatmentPlanProvider =
    StateNotifierProvider<TreatmentPlanNotifier, TreatmentPlanState>((ref) {
  return TreatmentPlanNotifier();
});
