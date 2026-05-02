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
  final principalNo = _principalNumber(member.memberNumber);
  final isPrincipal = member.memberNumber == principalNo;
  final list = await sanlamApi.getVisitList(
    principalNo,
    dependantNo: isPrincipal ? null : member.memberNumber,
  );
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
    // Dependants only see their own visits.
    final list = await sanlamApi.getVisitList(
      principalNo,
      dependantNo: member.memberNumber,
    );
    return list.map(Visit.fromJson).toList();
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
final visitsByMemberProvider =
    FutureProvider.family<List<Visit>, String>((ref, memberNo) async {
  final auth = ref.watch(authProvider);
  final loggedIn = auth.member;
  final principalNo = loggedIn != null
      ? _principalNumber(loggedIn.memberNumber)
      : _principalNumber(memberNo);
  final isPrincipal = memberNo == principalNo;
  final list = await sanlamApi.getVisitList(
    principalNo,
    dependantNo: isPrincipal ? null : memberNo,
  );
  return list.map(Visit.fromJson).toList();
});
