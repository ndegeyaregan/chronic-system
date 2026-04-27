import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class EmergencyRequest {
  final String id;
  final int? painLevel;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const EmergencyRequest({
    required this.id,
    this.painLevel,
    this.latitude,
    this.longitude,
    this.address,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    return EmergencyRequest(
      id: json['id'] as String,
      painLevel: json['pain_level'] != null
          ? int.tryParse(json['pain_level'].toString())
          : null,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'dispatched':
        return 'Help dispatched';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}

class EmergencyState {
  final bool isSubmitting;
  final bool isLoading;
  final bool submitted;
  final List<EmergencyRequest> pastRequests;
  final String? error;
  final String? successMessage;

  const EmergencyState({
    this.isSubmitting = false,
    this.isLoading = false,
    this.submitted = false,
    this.pastRequests = const [],
    this.error,
    this.successMessage,
  });

  EmergencyState copyWith({
    bool? isSubmitting,
    bool? isLoading,
    bool? submitted,
    List<EmergencyRequest>? pastRequests,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) =>
      EmergencyState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isLoading: isLoading ?? this.isLoading,
        submitted: submitted ?? this.submitted,
        pastRequests: pastRequests ?? this.pastRequests,
        error: clearError ? null : error,
        successMessage: clearSuccess ? null : successMessage,
      );
}

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  EmergencyNotifier() : super(const EmergencyState());

  Future<bool> requestAmbulance({
    required int painLevel,
    double? latitude,
    double? longitude,
    String? address,
    String? notes,
  }) async {
    state = state.copyWith(
        isSubmitting: true, clearError: true, clearSuccess: true);
    try {
      await dio.post('/emergency/ambulance', data: {
        'pain_level': painLevel,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'notes': notes,
      });
      state = state.copyWith(
        isSubmitting: false,
        submitted: true,
        successMessage:
            'Emergency request sent. Help is on the way. Stay calm.',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }

  void reset() {
    state = state.copyWith(
        submitted: false, clearError: true, clearSuccess: true);
  }
}

final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  return EmergencyNotifier();
});
