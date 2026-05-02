import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cycle.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

/// Cycle tracker state. Entries are cached locally (SharedPreferences) for
/// offline access AND mirrored to the backend (`/api/cycle`) so the data
/// follows the member across devices. Sync is best-effort — failures are
/// swallowed and the local cache remains the source of truth until the next
/// successful round-trip.

class CycleTrackerState {
  final bool loaded;
  final bool visible;
  final bool remindersEnabled;
  final List<CycleEntry> entries;
  final bool syncing;

  const CycleTrackerState({
    this.loaded = false,
    this.visible = false,
    this.remindersEnabled = true,
    this.entries = const [],
    this.syncing = false,
  });

  CycleStats get stats => CycleStats.from(entries);

  CycleTrackerState copyWith({
    bool? loaded,
    bool? visible,
    bool? remindersEnabled,
    List<CycleEntry>? entries,
    bool? syncing,
  }) =>
      CycleTrackerState(
        loaded: loaded ?? this.loaded,
        visible: visible ?? this.visible,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        entries: entries ?? this.entries,
        syncing: syncing ?? this.syncing,
      );
}

class CycleTrackerNotifier extends StateNotifier<CycleTrackerState> {
  CycleTrackerNotifier() : super(const CycleTrackerState()) {
    _load();
  }

  static const _keyEntries = 'cycle_entries_v1';
  static const _keyVisible = 'cycle_tracker_visible_v1';
  static const _keyReminders = 'cycle_tracker_reminders_v1';

  static const _baseNotifId = 720000;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEntries);
    final visible = prefs.getBool(_keyVisible) ?? false;
    final reminders = prefs.getBool(_keyReminders) ?? true;
    List<CycleEntry> entries = const [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        entries = list
            .map((e) => CycleEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
      } catch (_) {/* ignore corrupt data */}
    }
    state = state.copyWith(
      loaded: true,
      visible: visible,
      remindersEnabled: reminders,
      entries: entries,
    );
    await _rescheduleReminders();
    // Pull latest from backend in the background (won't block UI).
    unawaited(refreshFromBackend());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyEntries,
      jsonEncode(state.entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVisible, value);
    state = state.copyWith(visible: value);
    if (value) unawaited(refreshFromBackend());
  }

  Future<void> setRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminders, value);
    state = state.copyWith(remindersEnabled: value);
    await _rescheduleReminders();
  }

  Future<void> addEntry(CycleEntry entry) async {
    final list = [...state.entries, entry]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    state = state.copyWith(entries: list);
    await _persist();
    await _rescheduleReminders();
    unawaited(_pushEntry(entry));
  }

  Future<void> updateEntry(CycleEntry entry) async {
    final list = state.entries.map((e) => e.id == entry.id ? entry : e).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    state = state.copyWith(entries: list);
    await _persist();
    await _rescheduleReminders();
    unawaited(_pushEntry(entry));
  }

  Future<void> deleteEntry(String id) async {
    final list = state.entries.where((e) => e.id != id).toList();
    state = state.copyWith(entries: list);
    await _persist();
    await _rescheduleReminders();
    unawaited(_deleteRemote(id));
  }

  Future<void> endCurrentPeriod() async {
    if (state.entries.isEmpty) return;
    final last = state.entries.last;
    if (last.endDate != null) return;
    await updateEntry(last.copyWith(endDate: DateTime.now()));
  }

  // ── Backend sync ──────────────────────────────────────────────────────────

  /// Fetch the authoritative list from the server and merge with local cache.
  /// Server wins on conflict (latest data). Locally-only entries (failed push)
  /// remain so they can be retried on the next mutation.
  Future<void> refreshFromBackend() async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true);
    try {
      final resp = await dio.get('/cycle/mine');
      final rows = (resp.data as List).cast<Map<String, dynamic>>();
      final remote = rows.map(_entryFromRow).whereType<CycleEntry>().toList();
      final remoteIds = remote.map((e) => e.id).toSet();

      // Keep any local entries the server doesn't know about (offline drafts).
      final localOnly =
          state.entries.where((e) => !remoteIds.contains(e.id)).toList();

      final merged = [...remote, ...localOnly]
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      state = state.copyWith(entries: merged);
      await _persist();
      await _rescheduleReminders();

      // Push any local-only drafts the server hasn't seen yet.
      for (final e in localOnly) {
        unawaited(_pushEntry(e));
      }
    } on DioException {
      // Offline / not authenticated — fine, we'll retry later.
    } catch (_) {/* swallow */} finally {
      state = state.copyWith(syncing: false);
    }
  }

  Future<void> _pushEntry(CycleEntry e) async {
    try {
      await dio.post('/cycle', data: {
        'client_id': e.id,
        'start_date': _yyyyMmDd(e.startDate),
        'end_date': e.endDate == null ? null : _yyyyMmDd(e.endDate!),
        'flow': e.flow.id,
        'symptoms': e.symptoms,
        'mood': e.mood,
        'notes': e.notes,
      });
    } on DioException {/* offline — local cache holds it */}
    catch (_) {}
  }

  Future<void> _deleteRemote(String id) async {
    try {
      await dio.delete('/cycle/$id');
    } on DioException {/* ignore */}
    catch (_) {}
  }

  CycleEntry? _entryFromRow(Map<String, dynamic> row) {
    try {
      final clientId = (row['client_id'] ?? row['id']).toString();
      final start = DateTime.parse(row['start_date'].toString());
      final endRaw = row['end_date'];
      final end = endRaw == null ? null : DateTime.parse(endRaw.toString());
      List<String> symptoms = const [];
      final s = row['symptoms'];
      if (s is List) {
        symptoms = s.map((e) => e.toString()).toList();
      } else if (s is String && s.isNotEmpty) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            symptoms = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return CycleEntry(
        id: clientId,
        startDate: start,
        endDate: end,
        flow: FlowLevelX.fromId(row['flow']?.toString()),
        symptoms: symptoms,
        mood: row['mood']?.toString(),
        notes: row['notes']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _rescheduleReminders() async {
    // Always cancel previous schedules first.
    for (var i = 0; i < 4; i++) {
      await NotificationService.cancel(_baseNotifId + i);
    }
    if (!state.remindersEnabled || state.entries.isEmpty) return;
    final s = state.stats;
    final now = DateTime.now();

    Future<void> sched(int slot, DateTime at, String title, String body) async {
      if (at.isBefore(now)) return;
      await NotificationService.scheduleAt(
        id: _baseNotifId + slot,
        title: title,
        body: body,
        when: at,
        payload: 'cycle_reminder',
      );
    }

    // 09:00 local on each reminder date.
    DateTime morningOf(DateTime d) =>
        DateTime(d.year, d.month, d.day, 9, 0);

    if (s.predictedNextStart != null) {
      // 1 day before predicted period start
      await sched(
        0,
        morningOf(s.predictedNextStart!.subtract(const Duration(days: 1))),
        '🌸 Period coming tomorrow',
        'Your next period is predicted to start tomorrow. Stay prepared.',
      );
      // On predicted period start day
      await sched(
        1,
        morningOf(s.predictedNextStart!),
        '🌸 Period expected today',
        'Today is your predicted period start. Tap to log when it begins.',
      );
    }
    if (s.predictedOvulation != null) {
      // Day before ovulation (peak fertility)
      await sched(
        2,
        morningOf(s.predictedOvulation!.subtract(const Duration(days: 1))),
        '🌱 Fertile window — peak day tomorrow',
        'You are in your fertile window. Ovulation is predicted tomorrow.',
      );
      // Ovulation day
      await sched(
        3,
        morningOf(s.predictedOvulation!),
        '🌱 Predicted ovulation today',
        'Today is your predicted ovulation day.',
      );
    }
  }
}

final cycleTrackerProvider =
    StateNotifierProvider<CycleTrackerNotifier, CycleTrackerState>(
  (ref) => CycleTrackerNotifier(),
);
