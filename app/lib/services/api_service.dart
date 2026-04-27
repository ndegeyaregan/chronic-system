import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'offline_sync_service.dart';

/// Broadcast stream that fires `true` whenever the server returns 401
/// on a protected route — indicating the session has expired.
final sessionExpiredStream = StreamController<bool>.broadcast();

const _storage = FlutterSecureStorage();

Future<String?> _readToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kTokenKey);
  }
  return _storage.read(key: kTokenKey);
}

Future<void> _deleteToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
  } else {
    await _storage.delete(key: kTokenKey);
  }
}

/// Retries a failed request up to [maxRetries] times with exponential backoff.
/// Only retries on network/timeout errors — not 4xx or 5xx responses.
/// Auth routes (login, password) are NOT retried to avoid long waits.
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  _RetryInterceptor({required this.dio, this.maxRetries = 1}); // ignore: unused_element_parameter

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isNetworkError = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (!isNetworkError) {
      return handler.next(err);
    }

    // Never retry auth requests — user should see the error quickly
    final path = err.requestOptions.path;
    if (path.contains('/auth/')) {
      return handler.next(err);
    }

    final attempt = (err.requestOptions.extra['_retryCount'] as int?) ?? 0;
    if (attempt >= maxRetries) {
      return handler.next(err);
    }

    err.requestOptions.extra['_retryCount'] = attempt + 1;
    // Backoff: 1s, 2s
    await Future.delayed(Duration(seconds: 1 << attempt));
    try {
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

Dio _buildDio() {
  final d = Dio(BaseOptions(
    baseUrl: kBaseUrl,  // resolved from AppConfig.baseUrl (--dart-define=API_URL)
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 120),    // large file uploads
    receiveTimeout: const Duration(seconds: 30),
  ));

  d.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          // Only wipe the token for 401s on protected routes (expired/invalid session).
          // Auth-flow endpoints (/auth/login, /auth/change-password, etc.) return 401
          // for wrong credentials — deleting the token there would log the user out.
          if (!path.contains('/auth/')) {
            await _deleteToken();
            sessionExpiredStream.add(true); // Signal app to log out
          }
        }
        handler.next(error);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
    ),
  );

  d.interceptors.add(_RetryInterceptor(dio: d));

  // Queue failed writes for offline sync replay
  d.interceptors.add(InterceptorsWrapper(
    onError: (DioException err, ErrorInterceptorHandler handler) async {
      final isNetworkError = err.type == DioExceptionType.connectionError ||
          err.type == DioExceptionType.connectionTimeout;
      if (!isNetworkError) return handler.next(err);

      final method = err.requestOptions.method.toUpperCase();
      final path = err.requestOptions.path;

      // Only queue mutations, not reads or auth
      if ({'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method) &&
          !path.contains('/auth/')) {
        final data = err.requestOptions.data;
        await OfflineSyncService.enqueue(
          method: method,
          path: path,
          data: data is Map<String, dynamic> ? data : null,
        );
      }
      handler.next(err);
    },
  ));

  d.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    error: true,
  ));

  return d;
}

final dio = _buildDio();

String extractErrorMessage(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map) {
      return (data['message'] ?? data['error'] ?? 'An error occurred')
          .toString();
    }
    if (data is String && data.isNotEmpty) return data;
  } catch (_) {}
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Connection timed out. Please check your network.';
  }
  if (e.type == DioExceptionType.connectionError) {
    return 'No internet connection. Please try again.';
  }
  return e.message ?? 'An unexpected error occurred.';
}
