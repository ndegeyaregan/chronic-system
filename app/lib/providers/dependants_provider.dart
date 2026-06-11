// Loads dependants from `GetMemberDependent`. The Sanlam API is keyed
// on the principal's member number (suffix `-00`), so we derive the
// principal's number from the logged-in member and query that.
//
// Visibility rules (per business requirement):
//   - the logged-in user is never listed as a dependant of themselves;
//   - the displayed list is sourced exclusively from GetMemberDependent
//     so that we never fabricate family members (spouse or otherwise)
//     from benefit rows or member-number suffixes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dependant.dart';
import '../providers/auth_provider.dart';
import '../services/sanlam_api_service.dart';

String _principalNumber(String memberNo) {
  final dash = memberNo.lastIndexOf('-');
  if (dash == -1) return memberNo;
  return '${memberNo.substring(0, dash)}-00';
}

bool _isPrincipalOrSpouse(String relation) {
  final r = relation.trim().toLowerCase();
  return r == 'principal' || r == 'spouse';
}

final dependantsProvider = FutureProvider<List<Dependant>>((ref) async {
  final member = ref.watch(authProvider).member;
  if (member == null) throw Exception('Not authenticated');

  final principalNo = _principalNumber(member.memberNumber);
  final myNo = member.memberNumber;

  // GetMemberDependent is the single source of truth for who is on the
  // policy. Benefit rows and `-01` suffix guesses are intentionally not
  // used here because they led to phantom spouses for single members.
  final dependantRaw = await sanlamApi
      .getMemberDependent(principalNo)
      .catchError((_) => <Map<String, dynamic>>[]);

  final byMemberNo = <String, Dependant>{};
  for (final j in dependantRaw) {
    final d = Dependant.fromDependentJson(j);
    if (d.memberNo.isNotEmpty) byMemberNo[d.memberNo] = d;
  }

  // Some GetMemberDependent rows ship without a real name — for spouses
  // the API sometimes returns just the relation label ("Spouse") or an
  // empty string, which `fromDependentJson` then substitutes with the
  // member number. For each such row, fetch the real name from
  // GetMemberContactInfo so the list never displays the literal word
  // "Spouse" (or a bare member number) as if it were a person's name.
  bool needsRealName(Dependant d) {
    final n = d.name.trim();
    if (n.isEmpty) return true;
    if (n == d.memberNo) return true;
    final lower = n.toLowerCase();
    return lower == 'spouse' ||
        lower == 'principal' ||
        lower == d.relation.trim().toLowerCase();
  }

  final toEnrich =
      byMemberNo.values.where(needsRealName).map((d) => d.memberNo).toList();
  if (toEnrich.isNotEmpty) {
    final contacts = await Future.wait(toEnrich.map((mn) => sanlamApi
        .getMemberContactInfo(mn)
        .catchError((_) => <String, dynamic>{})));
    for (var i = 0; i < toEnrich.length; i++) {
      final mn = toEnrich[i];
      final realName =
          (contacts[i]['memberName'] ?? contacts[i]['MemberName'] ?? '')
              .toString()
              .trim();
      if (realName.isEmpty) continue;
      final existing = byMemberNo[mn]!;
      byMemberNo[mn] = Dependant(
        memberNo: existing.memberNo,
        name: realName,
        relation: existing.relation,
        scheme: existing.scheme,
        active: existing.active,
        benefit: existing.benefit,
      );
    }
  }

  // The signed-in member is never shown in their own dependants list.
  return byMemberNo.values.where((d) => d.memberNo != myNo).toList();
});

/// Whether the signed-in member is allowed to view/manage other
/// dependants. Per business rules only the principal and spouse can
/// see other family members; child dependants only see themselves.
final canViewDependantsProvider = Provider<bool>((ref) {
  final member = ref.watch(authProvider).member;
  if (member == null) return false;
  final relation = (member.relation ?? '').trim().toLowerCase();
  if (relation.isNotEmpty) return _isPrincipalOrSpouse(relation);
  // Fallback: derive from member-number suffix (-00 principal, -01 spouse).
  final suffix = member.memberNumber.split('-').last;
  return suffix == '00' || suffix == '01';
});
