import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visit.dart';
import '../models/visit_line.dart';
import '../providers/auth_provider.dart';
import '../providers/dependants_provider.dart';
import '../services/sanlam_api_service.dart';

String _principalNumber(String memberNo) {
  final dash = memberNo.lastIndexOf('-');
  if (dash == -1) return memberNo;
  return '${memberNo.substring(0, dash)}-00';
}

/// All visits/claims visible to the authenticated member.
///
/// The Sanlam `GetVisitList` endpoint always expects the principal's
/// `MemberNo`, plus an optional `DependantNo`. If the logged-in user is
/// a dependant we pass their number in `DependantNo`; principals see
/// their own visits with no `DependantNo`.
final visitsProvider = FutureProvider<List<Visit>>((ref) async {
  final member = ref.watch(authProvider).member;
  if (member == null) throw Exception('Not authenticated');
  // Always call with the signed-in member as MemberNo so the request
  // matches the JWT subject (Sanlam rejects mismatches).
  final list = await sanlamApi.getVisitList(member.memberNumber);
  return list.map(Visit.fromJson).toList();
});

/// Visit line items for a specific (memberNo, visitId) pair.
///
/// `memberNo` is the patient (principal or dependant). The Sanlam API
/// expects the principal's `MemberNo` and, for dependants, the
/// dependant's number in `DependantNo`.
final visitLinesProvider =
    FutureProvider.family<List<VisitLine>, (String, String)>(
        (ref, args) async {
  final (memberNo, visitId) = args;
  final auth = ref.watch(authProvider);
  final loggedIn = auth.member;
  // Sanlam rejects requests whose MemberNo doesn't match the signed-in
  // JWT subject. When a dependant views their own claim we must call
  // with the dependant's own number as MemberNo (no DependantNo).
  if (loggedIn != null && loggedIn.memberNumber == memberNo) {
    final list = await sanlamApi.getVisitSummary(memberNo, visitId);
    return list.map(VisitLine.fromJson).toList();
  }
  final principalNo = loggedIn != null
      ? _principalNumber(loggedIn.memberNumber)
      : _principalNumber(memberNo);
  final isPrincipal = memberNo == principalNo;
  final list = await sanlamApi.getVisitSummary(
    principalNo,
    visitId,
    dependantNo: isPrincipal ? null : memberNo,
  );
  return list.map(VisitLine.fromJson).toList();
});

/// Family-wide visits — principal + every dependant merged into one list.
///
/// `GetMemberPlanBenefit` returns a family-shared pool, but `GetVisitList`
/// only returns claims for one person at a time. This provider fans out
/// across the principal and all dependants so the Benefits screen can
/// show real, family-correct YTD spend & analytics.
///
/// When the logged-in user is a dependant we still scope to just their
/// own visits — they see only their own claims.
final familyVisitsProvider = FutureProvider<List<Visit>>((ref) async {
  final member = ref.watch(authProvider).member;
  if (member == null) throw Exception('Not authenticated');
  final principalNo = _principalNumber(member.memberNumber);
  final isPrincipal = member.memberNumber == principalNo;

  if (!isPrincipal) {
    // Dependants only see their own visits. The Sanlam JWT is signed
    // for the dependant, so we must call with their own number as
    // `MemberNo` (server rejects mismatched principal numbers with
    // "member number is not matching with signed member no").
    try {
      final list = await sanlamApi.getVisitList(member.memberNumber);
      return list.map(Visit.fromJson).toList();
    } on SanlamApiException catch (e) {
      // Treat "no records" / "not matching" as empty so the UI shows a
      // friendly empty state instead of a scary error.
      final d = e.description.toLowerCase();
      if (d.contains('not matching') ||
          d.contains('no record') ||
          d.contains('not found')) {
        return const <Visit>[];
      }
      rethrow;
    }
  }

  // Principal: pull principal visits + every dependant's visits in parallel.
  final dependants = await ref.watch(dependantsProvider.future);

  final futures = <Future<List<Map<String, dynamic>>>>[
    sanlamApi.getVisitList(principalNo),
    ...dependants
        .where((d) => d.memberNo.isNotEmpty && d.memberNo != principalNo)
        .map((d) => sanlamApi
            .getVisitList(principalNo, dependantNo: d.memberNo)
            .catchError(
                (_) => const <Map<String, dynamic>>[])),
  ];

  final results = await Future.wait(futures);
  final merged = <Visit>[];
  for (final r in results) {
    for (final j in r) {
      merged.add(Visit.fromJson(j));
    }
  }
  return merged;
});

/// Visits for a given memberNo — used for dependant recent claims.
///
/// The Sanlam endpoint expects the principal's `MemberNo` together with
/// the dependant's number in `DependantNo`. When [memberNo] is the
/// principal itself we omit `DependantNo`.
///
/// The Sanlam API sometimes returns the principal's claims as a fallback
/// when a dependant has no visits (instead of an empty list). To guard
/// against this, the dependant result is cross-checked against the
/// principal's claim IDs and any matching visits are stripped out, so the
/// dependant detail screen only ever shows that dependant's own claims.
final visitsByMemberProvider =
    FutureProvider.family<List<Visit>, String>((ref, memberNo) async {
  final auth = ref.watch(authProvider);
  final loggedIn = auth.member;
  // When the requested member IS the signed-in user, call directly with
  // their number (Sanlam rejects requests whose MemberNo doesn't match the
  // JWT subject). No cross-check needed — it's their own claims.
  if (loggedIn != null && loggedIn.memberNumber == memberNo) {
    final list = await sanlamApi.getVisitList(memberNo);
    return list.map(Visit.fromJson).toList();
  }
  final principalNo = loggedIn != null
      ? _principalNumber(loggedIn.memberNumber)
      : _principalNumber(memberNo);
  final isPrincipal = memberNo == principalNo;
  List<Map<String, dynamic>> list;
  try {
    list = await sanlamApi.getVisitList(
      principalNo,
      dependantNo: isPrincipal ? null : memberNo,
    );
  } on SanlamApiException catch (e) {
    final d = e.description.toLowerCase();
    if (d.contains('no record') ||
        d.contains('not found') ||
        d.contains('not matching')) {
      return const <Visit>[];
    }
    rethrow;
  }
  final visits = list.map(Visit.fromJson).toList();

  // For a principal query there is nothing to filter against.
  if (isPrincipal) return visits;

  // Fetch the principal's own claim IDs and remove any that leaked into the
  // dependant result. If the dependant truly has no claims this will produce
  // an empty list so the UI shows "No claims" rather than the principal's.
  try {
    final principalRaw = await sanlamApi.getVisitList(principalNo);
    final principalIds = {
      for (final j in principalRaw)
        (j['visitId'] ?? j['VisitId'] ?? '').toString()
    };
    return visits
        .where((v) => v.visitId.isNotEmpty && !principalIds.contains(v.visitId))
        .toList();
  } catch (_) {
    // If the cross-check itself fails, return whatever the API gave us.
    return visits;
  }
});
