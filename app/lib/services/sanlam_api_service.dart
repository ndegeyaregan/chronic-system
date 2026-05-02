import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../core/constants.dart';
import 'api_service.dart' show sessionExpiredStream;

/// In-memory holder for the current Sanlam JWT.
/// Set by AuthNotifier after a successful Sanlam login.
String? currentSanlamToken;

String? _currentSanlamToken() => currentSanlamToken;

class SanlamApiException implements Exception {
  final String status;
  final String description;
  const SanlamApiException(this.status, this.description);
  @override
  String toString() => 'SanlamApiException($status): $description';
}

class SanlamApiService {
  late final Dio _dio;

  SanlamApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.sanlamApiBase,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _currentSanlamToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          sessionExpiredStream.add(true);
        }
        handler.next(error);
      },
    ));
  }

  Map<String, dynamic> _unwrap(dynamic responseData) {
    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(responseData)) as Map);
    final status = (map['status'] ?? '').toString();
    final description = (map['description'] ?? '').toString();
    if (status != 'OK') {
      throw SanlamApiException(status, description);
    }
    return Map<String, dynamic>.from(map['data'] as Map? ?? {});
  }

  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(responseData)) as Map);
    final status = (map['status'] ?? '').toString();
    final description = (map['description'] ?? '').toString();
    if (status != 'OK') {
      // Treat "no <thing> found / not found / no records" as empty list,
      // not as an error — the UI shows a friendly empty state instead.
      final desc = description.toLowerCase();
      final looksEmpty = desc.contains('not found') ||
          desc.contains('no record') ||
          RegExp(r'\bno\b.*\b(found|exist|available)\b').hasMatch(desc);
      if (looksEmpty) return [];
      throw SanlamApiException(status, description);
    }
    final data = map['data'];
    if (data == null) return [];
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await _dio.post('login', data: {
      'username': username,
      'password': password,
    });
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getMemberPlanBenefit(
      String memberNo) async {
    final response =
        await _dio.post('GetMemberPlanBenefit', data: {'MemberNo': memberNo});
    return _unwrap(response.data);
  }

  /// Returns the corporate benefits + facility-specific co-pays for a member.
  /// Endpoint: `POST GetCoPay` → `{ data: [{ corpName, corpBenefits[], coPays[] }] }`
  /// We surface the first entry (members typically have a single corp).
  Future<Map<String, dynamic>> getCoPay(String memberNo) async {
    final response =
        await _dio.post('GetCoPay', data: {'MemberNo': memberNo});
    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
    final st = (map['status'] ?? '').toString();
    if (st != 'OK') {
      throw SanlamApiException(st, (map['description'] ?? '').toString());
    }
    final data = map['data'];
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<Map<String, dynamic>>> getPlanBenefitList(
      String memberNo) async {
    final response =
        await _dio.post('GetPlanBenefitList', data: {'MemberNo': memberNo});
    return _unwrapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getMemberDependent(
      String memberNo) async {
    final response =
        await _dio.post('GetMemberDependent', data: {'MemberNo': memberNo});
    return _unwrapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getVisitList(String memberNo,
      {String? dependantNo}) async {
    final body = <String, dynamic>{'MemberNo': memberNo};
    if (dependantNo != null && dependantNo.isNotEmpty) {
      body['DependantNo'] = dependantNo;
    }
    final response = await _dio.post('GetVisitList', data: body);
    return _unwrapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getVisitSummary(
      String memberNo, String visitId,
      {String? dependantNo}) async {
    final body = <String, dynamic>{
      'MemberNo': memberNo,
      'VisitId': visitId,
    };
    if (dependantNo != null && dependantNo.isNotEmpty) {
      body['DependantNo'] = dependantNo;
    }
    final response = await _dio.post('GetVisitSummary', data: body);
    return _unwrapList(response.data);
  }

  Future<Map<String, dynamic>> getVisitReport(
      String memberNo, String visitId,
      {String? dependantNo}) async {
    final body = <String, dynamic>{
      'MemberNo': memberNo,
      'VisitId': visitId,
    };
    if (dependantNo != null && dependantNo.isNotEmpty) {
      body['DependantNo'] = dependantNo;
    }
    final response = await _dio.post('GetVisitReport', data: body);
    return _unwrap(response.data);
  }

  /// Pre-authorisation requests for a member.
  ///
  /// Optional filters:
  ///  - [claimNo] — fetch a single request
  ///  - [status]  — `Open | Approved | Rejected | Cancelled`
  ///
  /// The endpoint returns `status: "OK"` with `data: []` when nothing
  /// matches, which we surface as an empty list (not an error).
  Future<List<Map<String, dynamic>>> getPreAuthRequests(
    String memberNo, {
    String? claimNo,
    String? status,
  }) async {
    final body = <String, dynamic>{'MemberNo': memberNo};
    if (claimNo != null && claimNo.isNotEmpty) body['claimNo'] = claimNo;
    if (status != null && status.isNotEmpty) body['Status'] = status;

    final response = await _dio.post('GetPreAuthRequests', data: body);

    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
    final st = (map['status'] ?? '').toString();
    if (st != 'OK') {
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final looksEmpty = desc.contains('not found') ||
          desc.contains('no record') ||
          RegExp(r'\bno\b.*\b(found|exist|available)\b').hasMatch(desc);
      if (looksEmpty) return [];
      throw SanlamApiException(st, (map['description'] ?? '').toString());
    }
    final data = map['data'];
    if (data == null) return [];
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Prescriptions dispatched (or pending dispatch) to the member's pharmacy.
  ///
  /// Endpoint: `POST GetPriscriptions` (upstream spelling).
  /// Optional [claimNo] narrows the result to a single pre-auth/claim.
  ///
  /// The endpoint sometimes returns `data` as a single object (one
  /// prescription) and sometimes as a list. Both shapes are normalised
  /// here. An "OK" response with no records is treated as an empty list.
  Future<List<Map<String, dynamic>>> getPrescriptions(
    String memberNo, {
    String? claimNo,
  }) async {
    final body = <String, dynamic>{'memberNo': memberNo};
    if (claimNo != null && claimNo.isNotEmpty) body['claimNo'] = claimNo;

    final response = await _dio.post('GetPrescriptions', data: body);

    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
    final st = (map['status'] ?? '').toString();
    if (st != 'OK') {
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final looksEmpty = desc.contains('not found') ||
          desc.contains('no record') ||
          RegExp(r'\bno\b.*\b(found|exist|available)\b').hasMatch(desc);
      if (looksEmpty) return [];
      throw SanlamApiException(st, (map['description'] ?? '').toString());
    }
    final data = map['data'];
    if (data == null) return [];
    if (data is List) {
      return data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchInstitution({
    String? name,
    String? city,
    String? mField,
  }) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (city != null && city.isNotEmpty) body['city'] = city;
    if (mField != null && mField.isNotEmpty) body['mField'] = mField;

    final response = await _dio.post('searchInstitution', data: body);

    final map = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map);
    final st = (map['status'] ?? '').toString();
    if (st != 'OK') {
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final looksEmpty = desc.contains('not found') ||
          desc.contains('no record') ||
          RegExp(r'\bno\b.*\b(found|exist|available)\b').hasMatch(desc);
      if (looksEmpty) return [];
      throw SanlamApiException(st, (map['description'] ?? '').toString());
    }
    final data = map['data'];
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    return [];
  }

  // ── Registration & password recovery ────────────────────────────────────

  /// Verify member exists prior to registration.
  /// Endpoint: `POST SearchForReg` — no auth required.
  /// Returns the member info map on success; throws [SanlamApiException] on
  /// "Member details not found." or other failure.
  Future<Map<String, dynamic>> searchForReg({
    required String memberNo,
    required String lastName,
    required String dob, // expected upstream format: yyyy-MM-dd
  }) async {
    final response = await _dio.post('SearchForReg', data: {
      'MemberNo': memberNo,
      'LastName': lastName,
      'DOB': dob,
    });
    return _unwrap(response.data);
  }

  /// Create the member's app account on the Sanlam server.
  /// Endpoint: `POST RegMember` — no auth required.
  /// Note: the server expects `username` (= MemberNo) and `password`.
  Future<Map<String, dynamic>> regMember({
    required String memberNo,
    required String password,
  }) async {
    final response = await _dio.post('RegMember', data: {
      'username': memberNo,
      'password': password,
    });
    return _unwrap(response.data);
  }

  /// Send a one-time PIN to the member's email or mobile.
  /// Endpoint: `POST SendOTP` — no auth required.
  /// [sendMode] is `1` for Email, `2` for SMS. Pass [email] for mode 1 and
  /// [mobile] for mode 2 (must be the value registered against the member).
  Future<Map<String, dynamic>> sendOtp({
    required String memberNo,
    required int sendMode,
    String? email,
    String? mobile,
  }) async {
    final body = <String, dynamic>{
      'MemberNo': memberNo,
      'SendMode': sendMode,
    };
    if (email != null && email.isNotEmpty) body['Email'] = email;
    if (mobile != null && mobile.isNotEmpty) body['MobileNo'] = mobile;
    final response = await _dio.post('SendOTP', data: body);
    return _unwrap(response.data);
  }

  /// Verify the OTP entered by the member.
  /// Endpoint: `POST VerifyOTP` — no auth required.
  /// On success the response includes a Bearer `accessToken` that authorises
  /// the subsequent `ResetPassword` call.
  Future<Map<String, dynamic>> verifyOtp({
    required String memberNo,
    required String otp,
  }) async {
    final response = await _dio.post('VerifyOTP', data: {
      'MemberNo': memberNo,
      'Otp': otp,
    });
    return _unwrap(response.data);
  }

  /// Set a new password after OTP verification.
  /// Endpoint: `POST ResetPassword` — requires the Bearer token returned by
  /// [verifyOtp]. We pass it explicitly (rather than relying on the global
  /// session token) so the user does not need to be logged-in first.
  /// Returns the fresh login payload (same shape as `/login`).
  Future<Map<String, dynamic>> resetPassword({
    required String memberNo,
    required String newPassword,
    required String accessToken,
  }) async {
    final response = await _dio.post(
      'ResetPassword',
      data: {'username': memberNo, 'password': newPassword},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _unwrap(response.data);
  }

  /// Get the member's contact info (mobile, email, dependentCount).
  /// Endpoint: `POST GetMemberContactInfo` — requires Bearer.
  Future<Map<String, dynamic>> getMemberContactInfo(String memberNo) async {
    final response = await _dio
        .post('GetMemberContactInfo', data: {'MemberNo': memberNo});
    return _unwrap(response.data);
  }

  /// Get the member's profile photo as raw base64 (no data-URL prefix).
  /// Endpoint: `POST GetMemberPhoto` — requires Bearer.
  /// Returns an empty string when no photo is set.
  Future<String> getMemberPhoto(String memberNo) async {
    final response =
        await _dio.post('GetMemberPhoto', data: {'MemberNo': memberNo});
    final data = _unwrap(response.data);
    return (data['profilePhoto'] ?? data['ProfilePhoto'] ?? '').toString();
  }

  /// Update the member's contact details. Both [mobile] and [email] are
  /// mandatory on the Sanlam side.
  /// Endpoint: `POST UpdateContactInfo` — requires Bearer.
  Future<Map<String, dynamic>> updateContactInfo({
    required String memberNo,
    required String mobile,
    required String email,
  }) async {
    final response = await _dio.post('UpdateContactInfo', data: {
      'MemberNo': memberNo,
      'Mobile': mobile,
      'Email': email,
    });
    return _unwrap(response.data);
  }

  /// Replace the member's profile photo. [photoBase64] must be the raw
  /// base64 (no `data:image/...` prefix).
  /// Endpoint: `POST UpdatePhoto` — requires Bearer.
  Future<Map<String, dynamic>> updatePhoto({
    required String memberNo,
    required String photoBase64,
  }) async {
    final response = await _dio.post('UpdatePhoto', data: {
      'MemberNo': memberNo,
      'Photo': photoBase64,
    });
    return _unwrap(response.data);
  }

  /// Member confirms or disputes a visit.
  /// [visitStatus]: 0 = unconfirmed, 1 = agree, 2 = disagree.
  /// Endpoint: `POST UpdateVisitStatus` — requires Bearer.
  Future<Map<String, dynamic>> updateVisitStatus({
    required String memberNo,
    required String visitId,
    required int visitStatus,
    String? dependentNo,
  }) async {
    final body = <String, dynamic>{
      'MemberNo': memberNo,
      'VisitId': visitId,
      'VisitStatus': visitStatus,
    };
    if (dependentNo != null && dependentNo.isNotEmpty) {
      body['DependentNo'] = dependentNo;
    }
    final response = await _dio.post('UpdateVisitStatus', data: body);
    return _unwrap(response.data);
  }
}

final sanlamApi = SanlamApiService();

Future<void> saveSanlamToken(String token) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSanlamTokenKey, token);
  } else {
    const storage = FlutterSecureStorage();
    await storage.write(key: kSanlamTokenKey, value: token);
  }
}

Future<String?> readSanlamToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSanlamTokenKey);
  }
  const storage = FlutterSecureStorage();
  return storage.read(key: kSanlamTokenKey);
}

Future<void> deleteSanlamToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSanlamTokenKey);
  } else {
    const storage = FlutterSecureStorage();
    await storage.delete(key: kSanlamTokenKey);
  }
}
