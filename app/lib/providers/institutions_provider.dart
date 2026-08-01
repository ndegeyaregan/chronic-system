import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/institution.dart';
import '../services/api_service.dart';
import '../services/institution_sync_service.dart';

class InstitutionsState {
  final List<Institution> items;
  final String? category;
  final String search;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String? lastSyncMessage;
  final double? userLat;
  final double? userLng;

  const InstitutionsState({
    this.items = const [],
    this.category,
    this.search = '',
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSyncMessage,
    this.userLat,
    this.userLng,
  });

  InstitutionsState copyWith({
    List<Institution>? items,
    Object? category = _sentinel,
    String? search,
    bool? isLoading,
    bool? isSyncing,
    Object? error = _sentinel,
    Object? lastSyncMessage = _sentinel,
    double? userLat,
    double? userLng,
  }) =>
      InstitutionsState(
        items: items ?? this.items,
        category: identical(category, _sentinel)
            ? this.category
            : category as String?,
        search: search ?? this.search,
        isLoading: isLoading ?? this.isLoading,
        isSyncing: isSyncing ?? this.isSyncing,
        error: identical(error, _sentinel) ? this.error : error as String?,
        lastSyncMessage: identical(lastSyncMessage, _sentinel)
            ? this.lastSyncMessage
            : lastSyncMessage as String?,
        userLat: userLat ?? this.userLat,
        userLng: userLng ?? this.userLng,
      );
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

const _sentinel = Object();

class InstitutionsNotifier extends StateNotifier<InstitutionsState> {
  InstitutionsNotifier() : super(const InstitutionsState()) {
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await fetch();
  }

  Future<void> setCategory(String? category) async {
    state = state.copyWith(category: category);
    await fetch();
  }

  Future<void> setSearch(String search) async {
    state = state.copyWith(search: search);
    await fetch();
  }

  /// Records the member's current position and re-sorts the already-loaded
  /// facilities nearest-first, without a network round trip.
  void setUserLocation(double lat, double lng) {
    state = state.copyWith(userLat: lat, userLng: lng);
    final list = List<Institution>.from(state.items);
    _sortItems(list);
    state = state.copyWith(items: list);
  }

  void _sortItems(List<Institution> list) {
    final lat = state.userLat;
    final lng = state.userLng;
    if (lat != null && lng != null) {
      // Facilities missing coordinates sort to the bottom rather than
      // breaking the list.
      list.sort((a, b) {
        final da = _haversineKm(lat, lng, a.latitude ?? 9999, a.longitude ?? 9999);
        final db = _haversineKm(lat, lng, b.latitude ?? 9999, b.longitude ?? 9999);
        return da.compareTo(db);
      });
    } else {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Pull from our own backend so the facility finder reflects whatever
      // the admin portal has curated (added, suspended, deleted). The
      // backend already filters out suspended & soft-deleted rows by
      // default, so users only ever see active facilities.
      final params = <String, dynamic>{'includeSuspended': 'true'};
      final cat = state.category;
      if (cat != null && cat.isNotEmpty) params['category'] = cat;
      final q = state.search.trim();
      if (q.isNotEmpty) params['search'] = q;

      final resp = await dio.get('/institutions', queryParameters: params);
      final data = resp.data;
      final raw = data is List ? data : <dynamic>[];
      final list = raw
          .whereType<Map>()
          .map((e) =>
              Institution.fromBackendJson(Map<String, dynamic>.from(e)))
          .where((i) => i.name.isNotEmpty)
          .toList();
      _sortItems(list);
      state = state.copyWith(items: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString() ??
                'Failed to load facilities'
            : 'Failed to load facilities',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Calls the Sanlam Member API to fetch all institutions and pushes them
  /// to the backend, then refreshes the local view.
  Future<void> syncFromSanlam({bool silent = false}) async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, error: null, lastSyncMessage: null);
    try {
      final result = await institutionSyncService.syncFromSanlam();
      final received = result['received'] ?? 0;
      final h = result['hospitals_upserted'] ?? 0;
      final p = result['pharmacies_upserted'] ?? 0;
      state = state.copyWith(
        isSyncing: false,
        lastSyncMessage:
            silent ? null : 'Synced $received facilities ($h hospitals, $p pharmacies)',
      );
      await fetch();
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: silent ? null : 'Sync failed: $e',
      );
    }
  }
}

final institutionsProvider =
    StateNotifierProvider<InstitutionsNotifier, InstitutionsState>(
  (ref) => InstitutionsNotifier(),
);
