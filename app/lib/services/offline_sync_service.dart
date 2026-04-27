import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'api_service.dart';

const _kSyncBox = 'offline_sync_queue';

/// Queued request stored in Hive for replay when connectivity returns.
class _QueuedRequest {
  final String method; // POST, PUT, PATCH, DELETE
  final String path;
  final Map<String, dynamic>? data;
  final int createdAt; // epoch ms

  _QueuedRequest({
    required this.method,
    required this.path,
    this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'data': data,
        'createdAt': createdAt,
      };

  factory _QueuedRequest.fromJson(Map<String, dynamic> json) => _QueuedRequest(
        method: json['method'] as String,
        path: json['path'] as String,
        data: json['data'] as Map<String, dynamic>?,
        createdAt: json['createdAt'] as int,
      );
}

/// Queue-based offline sync service.
///
/// When a write request (POST/PUT/PATCH/DELETE) fails due to network error,
/// call [enqueue] to save it. The service listens for connectivity changes and
/// replays queued requests in FIFO order when the device comes back online.
class OfflineSyncService {
  static late Box<String> _box;
  static StreamSubscription<List<ConnectivityResult>>? _connectSub;
  static bool _syncing = false;

  /// Number of pending requests (for UI badge).
  static final pendingCount = ValueNotifier<int>(0);

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_kSyncBox);
    pendingCount.value = _box.length;

    _connectSub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        flush();
      }
    });

    // Try to flush on startup in case there are pending items
    final current = await Connectivity().checkConnectivity();
    if (current.any((r) => r != ConnectivityResult.none)) {
      flush();
    }
  }

  /// Enqueue a failed request for later replay.
  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    final req = _QueuedRequest(
      method: method,
      path: path,
      data: data,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _box.add(jsonEncode(req.toJson()));
    pendingCount.value = _box.length;
    debugPrint('[OfflineSync] Queued $method $path (${_box.length} pending)');
  }

  /// Replay all queued requests in order.
  static Future<void> flush() async {
    if (_syncing || _box.isEmpty) return;
    _syncing = true;
    debugPrint('[OfflineSync] Flushing ${_box.length} queued requests…');

    final keys = _box.keys.toList();
    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;

      try {
        final req = _QueuedRequest.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);

        // Discard requests older than 24 hours
        final age = DateTime.now().millisecondsSinceEpoch - req.createdAt;
        if (age > const Duration(hours: 24).inMilliseconds) {
          await _box.delete(key);
          continue;
        }

        await _replay(req);
        await _box.delete(key);
        pendingCount.value = _box.length;
      } catch (e) {
        if (e is DioException &&
            (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout)) {
          // Still offline — stop flushing, will retry on next connectivity change
          break;
        }
        // Non-network error (e.g. 400/404) — discard the request
        debugPrint('[OfflineSync] Discarding failed request: $e');
        await _box.delete(key);
        pendingCount.value = _box.length;
      }
    }
    _syncing = false;
  }

  static Future<void> _replay(_QueuedRequest req) async {
    switch (req.method.toUpperCase()) {
      case 'POST':
        await dio.post(req.path, data: req.data);
      case 'PUT':
        await dio.put(req.path, data: req.data);
      case 'PATCH':
        await dio.patch(req.path, data: req.data);
      case 'DELETE':
        await dio.delete(req.path, data: req.data);
    }
    debugPrint('[OfflineSync] Replayed ${req.method} ${req.path}');
  }

  /// Check if the device currently has connectivity.
  static Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  static Future<void> dispose() async {
    await _connectSub?.cancel();
  }
}
