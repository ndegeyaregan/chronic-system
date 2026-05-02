import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prescription.dart';
import '../providers/auth_provider.dart';
import '../services/prescription_reminder_service.dart';
import '../services/sanlam_api_service.dart';

/// Optional claim-number filter. `null` (or empty) means "all prescriptions".
final prescriptionsClaimFilterProvider =
    StateProvider<String?>((_) => null);

/// Prescriptions for the signed-in member, optionally filtered by claim no.
final prescriptionsProvider =
    FutureProvider.family<List<Prescription>, String?>((ref, claimNo) async {
  final auth = ref.watch(authProvider);
  final member = auth.member;
  if (member == null) throw Exception('Not authenticated');

  final rows = await sanlamApi.getPrescriptions(
    member.memberNumber,
    claimNo: claimNo,
  );

  final list = rows.map(Prescription.fromJson).toList();

  // Group/sort: pending first, then partially issued, then fully issued.
  // Within each bucket, keep API order.
  int rank(Prescription p) {
    if (p.isPending) return 0;
    if (p.isPartiallyIssued) return 1;
    return 2;
  }

  list.sort((a, b) => rank(a).compareTo(rank(b)));

  // Schedule / cancel "go pick up your prescription" reminders. We only
  // reconcile against the unfiltered list (claimNo == null) so a search
  // doesn't accidentally cancel reminders for hidden prescriptions.
  if (claimNo == null || claimNo.isEmpty) {
    // Fire-and-forget: never let a notification error break the UI fetch.
    // ignore: discarded_futures
    PrescriptionReminderService.sync(list).catchError((_) {});
  }

  return list;
});

/// Convenience: all prescriptions for the signed-in member.
final allPrescriptionsProvider = FutureProvider<List<Prescription>>((ref) {
  final filter = ref.watch(prescriptionsClaimFilterProvider);
  return ref.watch(prescriptionsProvider(filter).future);
});
