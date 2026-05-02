import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preauth.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'preauth_provider.dart';

/// Persists the set of `claimNo`s for which we've already shown a
/// "decision arrived" notification, so we never notify twice for the
/// same approval/rejection — even across app restarts.
const _kSeenPreauthsKey = 'seen_preauth_decisions_v1';

/// Mounts a global listener that watches the member's pre-auth list and
/// surfaces a system notification (with sound) the first time a request
/// transitions into Approved / Rejected (within the last 14 days).
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

  static const _pollInterval = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSeen();
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
    setState(() {
      _seen = stored?.toSet() ?? <String>{};
      // First-ever launch: seed without notifying so users aren't blasted.
      _seeded = stored != null;
    });
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

    final decided = all.where((p) =>
        (p.status == PreauthStatus.approved ||
            p.status == PreauthStatus.rejected) &&
        p.isRecent());

    final newlyDecided = decided.where((p) => !seen.contains(p.claimNo)).toList();

    if (!_seeded) {
      // First load on this device — record everything as seen, don't notify.
      seen.addAll(decided.map((p) => p.claimNo));
      _seeded = true;
      await _persistSeen();
      return;
    }

    if (newlyDecided.isEmpty) return;

    for (final p in newlyDecided) {
      seen.add(p.claimNo);
      _fireNotification(p);
    }
    await _persistSeen();
  }

  void _fireNotification(Preauth p) {
    final isApproved = p.status == PreauthStatus.approved;
    final emoji = isApproved ? '✅' : '❌';
    final verb = isApproved ? 'approved' : 'rejected';
    final title = '$emoji Pre-authorisation $verb';

    final service = p.description.isNotEmpty
        ? p.description
        : (p.diagnosis.isNotEmpty ? p.diagnosis : 'Your request');

    String body = 'Your request for "$service" has been $verb.';
    if (isApproved && p.approvedAmount > 0) {
      final amt = p.approvedAmount.toStringAsFixed(0);
      body += ' Approved up to UGX $amt.';
    }
    if (!isApproved && p.insurerNote.isNotEmpty) {
      body += ' Note: ${p.insurerNote}';
    }

    // Stable id per claim — prevents duplicates if Android replays.
    final id = p.claimNo.hashCode & 0x7fffffff;

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
