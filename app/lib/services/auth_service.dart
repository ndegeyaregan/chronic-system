import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/member.dart';
import 'api_service.dart';

class AuthService {
  final _storage = kIsWeb ? null : const FlutterSecureStorage();

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

  Future<void> requestPasswordReset(
      String memberNumber, {String? phone, String? email}) async {
    await dio.post('/auth/forgot-password', data: {
      'member_number': memberNumber,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    });
  }

  Future<String> verifyOtp(String memberNumber, String otp) async {
    final response = await dio.post('/auth/verify-otp', data: {
      'member_number': memberNumber,
      'otp': otp,
    });
    final data = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
    return data['reset_token'] as String;
  }

  Future<void> resetPassword(
      String resetToken, String newPassword, String confirmPassword) async {
    await dio.post('/auth/reset-password', data: {
      'reset_token': resetToken,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } on DioException catch (_) {}
    await deleteToken();
  }
}

final authService = AuthService();
