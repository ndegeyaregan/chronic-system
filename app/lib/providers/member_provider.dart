import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sanlam_api_service.dart';
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
  MemberNotifier(this._ref, Member? initial)
      : super(MemberState(member: initial));

  final Ref _ref;

  void _syncToAuth(Member? m) {
    if (m == null) return;
    try {
      _ref.read(authProvider.notifier).updateMember(m);
    } catch (_) {}
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/members/me');
      final member = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberState(member: member);
      _syncToAuth(member);
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
      // Push to Sanlam first (their endpoint requires BOTH fields)
      final current = state.member;
      final mobileToSend = (phone ?? current?.phone ?? '').trim();
      final emailToSend = (email ?? current?.email ?? '').trim();
      final memberNo = current?.memberNumber;
      if (memberNo != null && memberNo.isNotEmpty) {
        try {
          await sanlamApi.updateContactInfo(
            memberNo: memberNo,
            mobile: mobileToSend,
            email: emailToSend,
          );
        } on SanlamApiException catch (e) {
          state = state.copyWith(isLoading: false, error: e.description);
          return false;
        }
      }
      // Mirror to local backend
      final response = await dio.put('/members/me', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      });
      final member = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(response.data)) as Map));
      state = MemberState(member: member);
      _syncToAuth(member);
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

  /// Upload a new profile picture (multipart). Returns true on success and
  /// updates the in-memory [Member] with the new URL.
  Future<bool> uploadProfilePicture(String filePath) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Push to Sanlam first as base64
      final memberNo = state.member?.memberNumber;
      if (memberNo != null && memberNo.isNotEmpty) {
        try {
          final bytes = await File(filePath).readAsBytes();
          final b64 = base64Encode(bytes);
          await sanlamApi.updatePhoto(
            memberNo: memberNo,
            photoBase64: b64,
          );
        } on SanlamApiException catch (e) {
          state = state.copyWith(isLoading: false, error: e.description);
          return false;
        }
      }
      // Mirror to local backend so we have a hosted URL for display
      final form = FormData.fromMap({
        'photo': await MultipartFile.fromFile(filePath),
      });
      final response = await dio.post('/me/profile-picture', data: form);
      final url = response.data is Map
          ? (response.data['profile_picture_url'] as String?)
          : null;
      final updated = state.member?.copyWith(profileIcon: url);
      state = MemberState(member: updated);
      _syncToAuth(updated);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: extractErrorMessage(e));
      return false;
    }
  }

  /// Remove the existing profile picture.
  Future<bool> removeProfilePicture() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await dio.delete('/me/profile-picture');
      final updated = state.member?.copyWith(clearProfileIcon: true);
      state = MemberState(member: updated);
      _syncToAuth(updated);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: extractErrorMessage(e));
      return false;
    }
  }
  /// Pull the latest contact + photo straight from Sanlam and persist locally.
  /// Used when opening the Profile screen so the user always sees fresh data.
  Future<void> refreshFromSanlam() async {
    final memberNo = state.member?.memberNumber;
    if (memberNo == null || memberNo.isEmpty) return;

    // 1) Contact info
    try {
      final c = await sanlamApi.getMemberContactInfo(memberNo);
      final mobile = (c['mobile'] ?? c['Mobile'] ?? '').toString().trim();
      final email = (c['email'] ?? c['Email'] ?? '').toString().trim();
      if (mobile.isNotEmpty || email.isNotEmpty) {
        // Persist to local DB so forgot-password etc. stay in sync
        try {
          final response = await dio.put('/members/me', data: {
            if (email.isNotEmpty) 'email': email,
            if (mobile.isNotEmpty) 'phone': mobile,
          });
          final member = Member.fromJson(Map<String, dynamic>.from(
              jsonDecode(jsonEncode(response.data)) as Map));
          state = MemberState(member: member);
          _syncToAuth(member);
        } on DioException catch (_) {
          // Even if local mirror fails, update in-memory member so UI shows fresh values
          final updated = state.member?.copyWith(
            phone: mobile.isNotEmpty ? mobile : null,
            email: email.isNotEmpty ? email : null,
          );
          state = state.copyWith(member: updated, isLoading: false);
          _syncToAuth(updated);
        }
      }
    } catch (_) {/* silent — keep cached values */}

    // 2) Photo (raw base64 — empty string if none). Persist via authService so
    // it survives app restarts and is available on the home screen.
    try {
      final b64 = await sanlamApi.getMemberPhoto(memberNo);
      final clean = b64.trim();
      final prefs = await SharedPreferences.getInstance();
      if (clean.isEmpty) {
        await prefs.remove(kSanlamPhotoKey);
        authService.cachedSanlamPhotoBase64 = null;
      } else {
        await prefs.setString(kSanlamPhotoKey, clean);
        authService.cachedSanlamPhotoBase64 = clean;
      }
      _ref.read(sanlamPhotoProvider.notifier).state =
          clean.isEmpty ? null : clean;
    } catch (_) {/* silent */}
  }
}

/// Raw base64 of the Sanlam-side profile photo (null if not yet loaded
/// or member has no photo on file). Seeded on app start from
/// SharedPreferences via [authService.cachedSanlamPhotoBase64].
final sanlamPhotoProvider =
    StateProvider<String?>((ref) => authService.cachedSanlamPhotoBase64);

final memberProvider =
    StateNotifierProvider<MemberNotifier, MemberState>((ref) {
  // Use ref.read so the notifier is created ONCE with the current auth member
  // and is NOT rebuilt whenever auth state changes — that was wiping locally
  // uploaded profile pictures and causing them to disappear intermittently.
  final authMember = ref.read(authProvider).member;
  return MemberNotifier(ref, authMember);
});
