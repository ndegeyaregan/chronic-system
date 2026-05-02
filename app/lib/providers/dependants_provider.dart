// Loads dependants from `GetMemberDependent`. The Sanlam API is keyed
// on the principal's member number (suffix `-00`), so we derive the
// principal's number from the logged-in member and query that.
//
// Visibility rules (per business requirement):
//   - the logged-in user is never listed as a dependant of themselves;
//   - principal and spouse are peers — they don't see each other in the
//     dependants list (they each still see other dependants).
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
  final raw = await sanlamApi.getMemberDependent(principalNo);
  final all = raw.map(Dependant.fromDependentJson).toList();

  final myNo = member.memberNumber;
  final myRelation = (member.relation ?? '').trim().toLowerCase();
  final hideSpouseSide = _isPrincipalOrSpouse(myRelation);

  return all.where((d) {
    if (d.memberNo == myNo) return false;
    if (hideSpouseSide && _isPrincipalOrSpouse(d.relation)) return false;
    return true;
  }).toList();
});
