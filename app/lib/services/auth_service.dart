import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/member.dart';
import 'api_service.dart';
import 'sanlam_api_service.dart';

class AuthService {
  final _storage = kIsWeb ? null : const FlutterSecureStorage();

  /// In-memory copy of the Sanlam profile photo (raw base64). Loaded from
  /// SharedPreferences on app start by [loadCachedSanlamPhoto] so the
  /// avatar shows immediately on the home screen, before the profile screen
  /// opens.
  String? cachedSanlamPhotoBase64;

  Future<void> loadCachedSanlamPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString(kSanlamPhotoKey);
    if (b64 != null && b64.isNotEmpty) cachedSanlamPhotoBase64 = b64;
  }

  Future<void> _saveSanlamPhoto(String? b64) async {
    final prefs = await SharedPreferences.getInstance();
    if (b64 == null || b64.isEmpty) {
      await prefs.remove(kSanlamPhotoKey);
      cachedSanlamPhotoBase64 = null;
    } else {
      await prefs.setString(kSanlamPhotoKey, b64);
      cachedSanlamPhotoBase64 = b64;
    }
  }

  Future<Map<String, dynamic>> loginWithMemberNumber(
      String memberNumber, String password) async {
    final response = await dio.post('/auth/login/member', data: {
      'member_number': memberNumber,
      'password': password,
    });
    return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
  }

  Future<Map<String, dynamic>> loginWithDOB(
      String lastName, String dob, String password) async {
    final response = await dio.post('/auth/login/member', data: {
      'last_name': lastName,
      'date_of_birth': dob,
      'password': password,
    });
    return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kTokenKey, token);
    } else {
      await _storage!.write(key: kTokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(kTokenKey);
    }
    return _storage!.read(key: kTokenKey);
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTokenKey);
    } else {
      await _storage!.delete(key: kTokenKey);
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    return !_isTokenExpired(token);
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp;
    } catch (_) {
      return true;
    }
  }

  Member? decodeTokenMember(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final memberJson =
          payload['member'] as Map<String, dynamic>? ?? payload;
      return Member.fromJson(memberJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> createPassword(
      String password, String confirmPassword) async {
    await dio.post('/auth/create-password', data: {
      'password': password,
      'confirm_password': confirmPassword,
    });
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// Send an OTP via the Sanlam Member API. Auto-detects send mode from the
  /// shape of [contact] — `@` ⇒ Email (mode 1), otherwise SMS (mode 2).
  Future<void> requestPasswordReset(
      String memberNumber, {String? phone, String? email}) async {
    final emailVal = (email ?? '').trim();
    final phoneVal = (phone ?? '').trim();
    if (emailVal.isNotEmpty) {
      await sanlamApi.sendOtp(
        memberNo: memberNumber,
        sendMode: 1,
        email: emailVal,
      );
    } else if (phoneVal.isNotEmpty) {
      await sanlamApi.sendOtp(
        memberNo: memberNumber,
        sendMode: 2,
        mobile: phoneVal,
      );
    } else {
      throw ArgumentError('Provide either an email or a phone number.');
    }
  }

  /// Step 1 of the new 2-step forgot-password flow. Asks the backend
  /// which channels (email / SMS) are available for this member and
  /// returns a map like:
  ///   { hasEmail: bool, hasPhone: bool, maskedEmail: '...', maskedPhone: '...' }
  Future<Map<String, dynamic>> lookupForgotPasswordContact(
      String memberNumber) async {
    final res = await dio.post(
      '/auth/sanlam/forgot-password/lookup',
      data: {'member_number': memberNumber},
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return const {};
  }

  /// Forgot-password flow with only the member number. The backend looks
  /// up the member's email/phone and asks Sanlam to send the OTP.
  /// Pass [sendMode] (1 = email, 2 = SMS) to force a specific channel.
  /// Returns a friendly message describing where the OTP was sent
  /// (e.g. "OTP sent to your email ed**@example.com").
  Future<String> requestPasswordResetByMemberNo(
    String memberNumber, {
    int? sendMode,
  }) async {
    final res = await dio.post(
      '/auth/sanlam/forgot-password',
      data: {
        'member_number': memberNumber,
        if (sendMode != null) 'send_mode': sendMode,
      },
    );
    final data = res.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'OTP sent.';
  }

  /// Verify the OTP. Returns the temporary Sanlam access token that
  /// authorises the subsequent [resetPassword] call.
  Future<String> verifyOtp(String memberNumber, String otp) async {
    final data = await sanlamApi.verifyOtp(memberNo: memberNumber, otp: otp);
    final token = (data['accessToken'] ?? '').toString();
    if (token.isEmpty) {
      throw const SanlamApiException('Error', 'OTP verification did not return a token.');
    }
    return token;
  }

  /// Reset the password on the Sanlam server. [resetToken] must be the
  /// access token returned by [verifyOtp]. After success the member can
  /// sign in normally with [newPassword].
  Future<void> resetPassword(
      String memberNumber, String resetToken, String newPassword) async {
    await sanlamApi.resetPassword(
      memberNo: memberNumber,
      newPassword: newPassword,
      accessToken: resetToken,
    );
  }

  /// Verify a member exists prior to creating an app account.
  /// Throws [SanlamApiException] if not found.
  Future<Map<String, dynamic>> searchForRegistration({
    required String memberNumber,
    required String lastName,
    required String dob,
  }) {
    return sanlamApi.searchForReg(
      memberNo: memberNumber,
      lastName: lastName,
      dob: dob,
    );
  }

  /// Create the member's app account on the Sanlam server.
  Future<void> registerMember({
    required String memberNumber,
    required String password,
  }) async {
    await sanlamApi.regMember(memberNo: memberNumber, password: password);
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } on DioException catch (_) {}
    await deleteToken();
    await deleteSanlamToken();
    currentSanlamToken = null;
    await deleteMember();
  }

  Future<Map<String, dynamic>> exchangeSanlamForLocal(
      String memberNumber, String sanlamToken) async {
    final response = await dio.post('/auth/sanlam-login', data: {
      'member_number': memberNumber,
      'sanlam_token': sanlamToken,
    });
    return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
  }

  Future<void> saveMember(Member member) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserKey, jsonEncode(member.toJson()));
  }

  Future<Member?> loadMember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kUserKey);
      if (raw == null || raw.isEmpty) return null;
      return Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteMember() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserKey);
  }

  Future<Member> loginSanlam(
      String memberNumber, String password) async {
    final data = await sanlamApi.login(memberNumber, password);
    Member member = Member.fromSanlamLogin(data);
    final sanlamToken = member.accessToken;
    if (sanlamToken != null && sanlamToken.isNotEmpty) {
      await saveSanlamToken(sanlamToken);
      currentSanlamToken = sanlamToken;

      // Pull the real name + contacts from Sanlam (login payload often only
      // has memberNo + accessToken). This stops "Unknown" / member-number-as-
      // first-name from ever reaching the UI or the JWT.
      try {
        final c = await sanlamApi.getMemberContactInfo(memberNumber);
        final memberName = (c['memberName'] ?? c['MemberName'] ?? '')
            .toString()
            .trim();
        final mobile = (c['mobile'] ?? c['Mobile'] ?? '').toString().trim();
        final email = (c['email'] ?? c['Email'] ?? '').toString().trim();
        if (memberName.isNotEmpty) {
          final parts = memberName.split(RegExp(r'\s+'));
          member = member.copyWith(
            firstName: parts.first,
            lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
          );
        }
        if (email.isNotEmpty) member = member.copyWith(email: email);
        if (mobile.isNotEmpty) member = member.copyWith(phone: mobile);
      } catch (_) {/* non-fatal */}

      // Cache the Sanlam profile photo so it's available on the home screen
      // immediately after login.
      try {
        final b64 = await sanlamApi.getMemberPhoto(memberNumber);
        await _saveSanlamPhoto(b64.trim().isEmpty ? null : b64.trim());
      } catch (_) {/* non-fatal */}

      final localData = await exchangeSanlamForLocal(memberNumber, sanlamToken);
      final localToken = (localData['token'] ?? '').toString();
      if (localToken.isNotEmpty) {
        await saveToken(localToken);
      }
      final localMemberJson = localData['member'] as Map<String, dynamic>?;
      final dbId = localMemberJson?['id']?.toString();
      final enriched = dbId != null ? member.copyWith(id: dbId) : member;
      await saveMember(enriched);
      return enriched;
    }
    return member;
  }
}

final authService = AuthService();
