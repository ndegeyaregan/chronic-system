import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preauth.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'preauth_provider.dart';

/// Persists the set of `claimNo|status` keys for which we've already shown a
/// notification, so we never notify twice for the same status transition —
/// even across app restarts. A single pre-auth can fire up to two
/// notifications: once when it first appears as Open, and once when it
/// transitions to Approved or Rejected.
const _kSeenPreauthsKey = 'seen_preauth_events_v2';

/// Mounts a global listener that watches the member's pre-auth list and
/// surfaces a system notification (with sound) the first time a request
/// is seen in Open / Approved / Rejected status (within the last 14 days).
///
/// Drop one [PreauthNotificationListener] near the top of the
/// authenticated widget tree. It renders nothing.
class PreauthNotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  const PreauthNotificationListener({super.key, required this.child});

  @override
  ConsumerState<PreauthNotificationListener> createState() =>
      _PreauthNotificationListenerState();
}

class _PreauthNotificationListenerState
    extends ConsumerState<PreauthNotificationListener>
    with WidgetsBindingObserver {
  Set<String>? _seen; // null until prefs are loaded
  bool _seeded = false; // prevents notifying for items we already had
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSeen();
    // Kick off an immediate refresh so the user doesn't have to wait a full
    // poll cycle for the first notification after login / app launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      // Re-process whatever's already loaded in case nothing changed
      // server-side but we missed an event while paused.
      final current = ref.read(allPreauthsProvider);
      current.whenData(_handleUpdate);
    }
  }

  void _refresh() {
    final auth = ref.read(authProvider);
    if (auth.member == null) return;
    ref.invalidate(allPreauthsProvider);
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kSeenPreauthsKey);
    if (!mounted) return;
    setState(() {
      _seen = stored?.toSet() ?? <String>{};
      // First-ever launch: seed without notifying so users aren't blasted.
      _seeded = stored != null;
    });
    // The provider may have already produced a value before _loadSeen
    // finished. ref.listen only fires on *changes*, so without this we'd
    // miss the first data event entirely and notifications would only
    // appear on the next 30-second poll (or, worse, never if the data
    // doesn't change). Process the current value right now.
    final current = ref.read(allPreauthsProvider);
    current.whenData(_handleUpdate);
  }

  Future<void> _persistSeen() async {
    final s = _seen;
    if (s == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSeenPreauthsKey, s.toList());
  }

  Future<void> _handleUpdate(List<Preauth> all) async {
    final seen = _seen;
    if (seen == null) return;

    String keyOf(Preauth p) => '${p.claimNo}|${p.status.name}';

    final relevant = all.where((p) =>
        (p.status == PreauthStatus.open ||
            p.status == PreauthStatus.approved ||
            p.status == PreauthStatus.rejected) &&
        p.claimNo.isNotEmpty);

    final newlySeen = relevant.where((p) => !seen.contains(keyOf(p))).toList();

    if (!_seeded) {
      // First load on this device — record everything as seen, don't notify.
      seen.addAll(relevant.map(keyOf));
      _seeded = true;
      await _persistSeen();
      return;
    }

    if (newlySeen.isEmpty) return;

    for (final p in newlySeen) {
      seen.add(keyOf(p));
      _fireNotification(p);
    }
    await _persistSeen();
  }

  void _fireNotification(Preauth p) {
    final String title;
    final String verb;
    switch (p.status) {
      case PreauthStatus.approved:
        title = '✅ Pre-authorisation approved';
        verb = 'approved';
        break;
      case PreauthStatus.rejected:
        title = '❌ Pre-authorisation rejected';
        verb = 'rejected';
        break;
      case PreauthStatus.open:
        title = '📨 Pre-authorisation received';
        verb = 'received and is being reviewed';
        break;
      default:
        return;
    }

    final service = p.description.isNotEmpty
        ? p.description
        : (p.diagnosis.isNotEmpty ? p.diagnosis : 'Your request');

    String body = 'Your request for "$service" has been $verb.';
    if (p.status == PreauthStatus.approved && p.approvedAmount > 0) {
      final amt = p.approvedAmount.toStringAsFixed(0);
      body += ' Approved up to UGX $amt.';
    }
    if (p.status == PreauthStatus.rejected && p.insurerNote.isNotEmpty) {
      body += ' Note: ${p.insurerNote}';
    }

    // Stable id per (claim, status) — prevents duplicates if Android replays,
    // and lets Open + decided notifications coexist without overwriting.
    final id = '${p.claimNo}:${p.status.name}'.hashCode & 0x7fffffff;

    NotificationService.show(
      id: id,
      title: title,
      body: body,
      payload: 'preauth:${p.claimNo}',
    ).catchError((Object e, _) {
      if (kDebugMode) debugPrint('Preauth notify failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the (no-filter) preauth feed. ref.listen fires whenever
    // the AsyncValue changes — including silent refreshes.
    ref.listen<AsyncValue<List<Preauth>>>(allPreauthsProvider, (prev, next) {
      next.whenData(_handleUpdate);
    });

    return widget.child;
  }
}
