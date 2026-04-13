import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class MemberState {
  final Member? member;
  final bool isLoading;
  final String? error;

  const MemberState({
    this.member,
    this.isLoading = false,
    this.error,
  });

  MemberState copyWith({
    Member? member,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      MemberState(
        member: member ?? this.member,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error,
      );
}

class MemberNotifier extends StateNotifier<MemberState> {
  MemberNotifier(Member? initial) : super(MemberState(member: initial));

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/members/me');
      final member = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberState(member: member);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
    }
  }

  Future<bool> updateContact({String? phone, String? email}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.put('/members/me', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      });
      final member = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberState(member: member);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }
  Future<bool> updateConditions(List<String> conditions) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.put('/members/me/conditions',
          data: {'conditions': conditions});
      final member = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberState(member: member);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: extractErrorMessage(e));
      return false;
    }
  }
}

final memberProvider =
    StateNotifierProvider<MemberNotifier, MemberState>((ref) {
  final authMember = ref.watch(authProvider).member;
  return MemberNotifier(authMember);
});
