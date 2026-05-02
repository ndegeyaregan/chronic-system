import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';
import 'notification_service.dart';

/// Tracks the first time the app sees each prescription as still-pending
/// and schedules a "go pick up your medication" reminder 24 h later.
///
/// Why client-side? The Sanlam `GetPriscriptions` payload has no date
/// fields, so the app cannot know when the doctor actually issued the
/// prescription. Instead we treat the *first time we observe it as
/// pending* as t=0. The clock therefore starts on first fetch (login or
/// refresh), and resets if the user clears app data.
///
/// Stored shape (in SharedPreferences under [_kKey]):
/// ```
/// { "PRHE-260428-347": "2026-04-30T15:00:00.000Z", ... }
/// ```
class PrescriptionReminderService {
  static const String _kKey = 'prescription_first_seen_v1';

  /// Notification IDs are kept in a stable range so we can cancel them
  /// later without colliding with other features.
  static const int _idBase = 9_100_000;

  /// Time between first observation and the reminder firing.
  static const Duration reminderDelay = Duration(hours: 24);

  /// Reconcile the first-seen map and scheduled notifications with the
  /// latest prescriptions list from the API. Safe to call on every
  /// successful fetch.
  static Future<void> sync(List<Prescription> prescriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    final map = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) => map[k] = v.toString());
      } catch (_) {
        // Corrupt cache — start fresh.
      }
    }

    final now = DateTime.now();
    final seenClaims = <String>{};

    for (final p in prescriptions) {
      final key = _key(p);
      if (key.isEmpty) continue;
      seenClaims.add(key);

      if (p.isFullyIssued) {
        // Already collected — drop any pending reminder + tracking entry.
        if (map.containsKey(key)) {
          await NotificationService.cancel(_notificationId(key));
          map.remove(key);
        }
        continue;
      }

      // Pending or partial — make sure it's tracked + scheduled.
      DateTime firstSeen;
      final existing = map[key];
      if (existing == null) {
        firstSeen = now;
        map[key] = now.toIso8601String();
      } else {
        firstSeen = DateTime.tryParse(existing) ?? now;
      }

      final fireAt = firstSeen.add(reminderDelay);
      // scheduleAt silently no-ops for past times. If we missed the
      // window (e.g. app was closed), fire it shortly so the member is
      // still nudged the next time they open the app.
      final when =
          fireAt.isBefore(now) ? now.add(const Duration(seconds: 5)) : fireAt;

      await NotificationService.cancel(_notificationId(key));
      await NotificationService.scheduleAt(
        id: _notificationId(key),
        title: '💊 Pick up your prescription',
        body: _reminderBody(p),
        when: when,
        payload: 'prescription:${p.claimNo}',
      );
    }

    // Garbage-collect entries for prescriptions that no longer come back
    // from the API at all (e.g. cancelled upstream).
    final stale = map.keys.where((k) => !seenClaims.contains(k)).toList();
    for (final k in stale) {
      await NotificationService.cancel(_notificationId(k));
      map.remove(k);
    }

    await prefs.setString(_kKey, jsonEncode(map));
  }

  /// Wipe all tracking + cancel pending reminders. Call on logout.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final k in decoded.keys) {
          await NotificationService.cancel(_notificationId(k));
        }
      } catch (_) {}
    }
    await prefs.remove(_kKey);
  }

  static String _key(Prescription p) {
    // claimNo + code uniquely identifies a single prescribed line.
    if (p.claimNo.isEmpty && p.code.isEmpty) return '';
    return '${p.claimNo}|${p.code}';
  }

  static int _notificationId(String key) {
    // Stable, non-negative 31-bit id derived from the key hash.
    return _idBase + (key.hashCode & 0x7FFFFFF);
  }

  static String _reminderBody(Prescription p) {
    final med = p.medication.isNotEmpty ? p.medication : 'your medication';
    final qty = p.qty > 0 ? ' (${p.qty - p.issuedQty} left)' : '';
    return "You haven't picked up $med$qty from your pharmacy yet. "
        'Please collect it soon — prescriptions can expire.';
  }
}
