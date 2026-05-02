import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/institution.dart';
import '../services/institution_sync_service.dart';
import '../services/sanlam_api_service.dart';

class InstitutionsState {
  final List<Institution> items;
  final String? category;
  final String search;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String? lastSyncMessage;

  const InstitutionsState({
    this.items = const [],
    this.category,
    this.search = '',
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSyncMessage,
  });

  InstitutionsState copyWith({
    List<Institution>? items,
    Object? category = _sentinel,
    String? search,
    bool? isLoading,
    bool? isSyncing,
    Object? error = _sentinel,
    Object? lastSyncMessage = _sentinel,
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
      );
}

const _sentinel = Object();

class InstitutionsNotifier extends StateNotifier<InstitutionsState> {
  InstitutionsNotifier() : super(const InstitutionsState()) {
    _bootstrap();
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

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Pull the full live list from the Sanlam Member API so the facility
      // finder always reflects the upstream catalogue (~690 facilities) and
      // not whatever happens to be in the local DB.
      final raw = await sanlamApi.searchInstitution();
      var list = raw
          .whereType<Map>()
          .map((e) =>
              Institution.fromSanlamJson(Map<String, dynamic>.from(e)))
          .where((i) => i.name.isNotEmpty)
          .toList();

      final cat = state.category;
      if (cat != null && cat.isNotEmpty) {
        list = list.where((i) => i.category == cat).toList();
      }
      final q = state.search.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((i) {
          final hay =
              '${i.name} ${i.city ?? ''} ${i.address ?? ''} ${i.street ?? ''} ${i.shortId ?? ''}'
                  .toLowerCase();
          return hay.contains(q);
        }).toList();
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
