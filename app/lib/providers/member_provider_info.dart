import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member_provider.dart';
import '../services/api_service.dart';

class MemberProviderInfoState {
  final MemberProvider? provider;
  final bool isLoading;
  final String? error;

  const MemberProviderInfoState({
    this.provider,
    this.isLoading = false,
    this.error,
  });

  MemberProviderInfoState copyWith({
    MemberProvider? provider,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearProvider = false,
  }) =>
      MemberProviderInfoState(
        provider: clearProvider ? null : (provider ?? this.provider),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class MemberProviderInfoNotifier
    extends StateNotifier<MemberProviderInfoState> {
  MemberProviderInfoNotifier() : super(const MemberProviderInfoState()) {
    fetchProvider();
  }

  Future<void> fetchProvider() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/members/me/provider');
      if (response.data != null) {
        final provider = MemberProvider.fromJson(Map<String, dynamic>.from(
            jsonDecode(jsonEncode(response.data)) as Map));
        state = MemberProviderInfoState(provider: provider);
      } else {
        state = const MemberProviderInfoState();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = const MemberProviderInfoState();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: extractErrorMessage(e),
        );
      }
    }
  }

  Future<bool> saveProvider({
    required String providerType,
    String? doctorName,
    String? doctorContact,
    String? doctorEmail,
    String? hospitalId,
    String? hospitalName,
    String? hospitalAddress,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final Response response;
      final data = {
        'provider_type': providerType,
        if (doctorName != null) 'doctor_name': doctorName,
        if (doctorContact != null) 'doctor_contact': doctorContact,
        if (doctorEmail != null) 'doctor_email': doctorEmail,
        if (hospitalId != null) 'hospital_id': hospitalId,
        if (hospitalName != null) 'hospital_name': hospitalName,
        if (hospitalAddress != null) 'hospital_address': hospitalAddress,
        if (notes != null) 'notes': notes,
      };
      if (state.provider != null) {
        response = await dio.put('/members/me/provider', data: data);
      } else {
        response = await dio.post('/members/me/provider', data: data);
      }
      final provider = MemberProvider.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberProviderInfoState(provider: provider);
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

final memberProviderInfoProvider = StateNotifierProvider<
    MemberProviderInfoNotifier, MemberProviderInfoState>((ref) {
  return MemberProviderInfoNotifier();
});
