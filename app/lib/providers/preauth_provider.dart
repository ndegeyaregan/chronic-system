import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/preauth.dart';
import '../providers/auth_provider.dart';
import '../services/sanlam_api_service.dart';

/// Pre-auth requests for the signed-in member, optionally filtered by status.
///
/// Pass `null` for "all". The Sanlam API does the filtering server-side,
/// so each filter selection re-fetches.
final preauthsProvider =
    FutureProvider.family<List<Preauth>, PreauthStatus?>((ref, statusFilter) async {
  final auth = ref.watch(authProvider);
  final member = auth.member;
  if (member == null) throw Exception('Not authenticated');

  final rows = await sanlamApi.getPreAuthRequests(
    member.memberNumber,
    status: statusFilter?.apiValue,
  );

  var list = rows.map(Preauth.fromJson).toList();

  // Belt-and-suspenders: enforce the filter client-side too. Some
  // upstream servers ignore the Status param and return everything.
  if (statusFilter != null) {
    list = list.where((p) => p.status == statusFilter).toList();
  }

  // Newest first — by parsed claimNo date, then by claimNo string as tiebreaker.
  list.sort((a, b) {
    final ad = a.requestDate;
    final bd = b.requestDate;
    if (ad != null && bd != null && ad != bd) return bd.compareTo(ad);
    if (ad == null && bd != null) return 1;
    if (bd == null && ad != null) return -1;
    return b.claimNo.compareTo(a.claimNo);
  });

  return list;
});

/// Convenience: all pre-auths (no filter).
final allPreauthsProvider = FutureProvider<List<Preauth>>((ref) {
  return ref.watch(preauthsProvider(null).future);
});
