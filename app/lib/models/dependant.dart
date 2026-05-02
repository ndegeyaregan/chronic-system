import 'benefit.dart';
import 'member.dart';

class Dependant {
  final String memberNo;
  final String name;
  final String relation;
  final String? scheme;
  final bool active;
  final Benefit? benefit;

  const Dependant({
    required this.memberNo,
    required this.name,
    required this.relation,
    this.scheme,
    this.active = true,
    this.benefit,
  });

  factory Dependant.fromBenefitJson(Map<String, dynamic> j) {
    final memberNo = (j['memberNo'] ?? j['MemberNo'] ?? '').toString();
    final benefit = Benefit.fromJson(j);
    return Dependant(
      memberNo: memberNo,
      name: benefit.name,
      relation: Member.relationFromMemberNumber(memberNo),
      benefit: benefit,
    );
  }

  /// Parses a row from `GetMemberDependent`.
  factory Dependant.fromDependentJson(Map<String, dynamic> j) {
    final memberNo = (j['memberNo'] ?? j['MemberNo'] ?? '').toString();
    final name =
        (j['memberName'] ?? j['name'] ?? j['MemberName'] ?? '').toString();
    final relation = (j['relation'] ?? j['Relation'] ?? '').toString();
    final statusRaw = j['status'];
    final active = statusRaw is bool
        ? statusRaw
        : statusRaw?.toString().toLowerCase() == 'true';
    return Dependant(
      memberNo: memberNo,
      name: name.isNotEmpty ? name : memberNo,
      relation: relation.isNotEmpty
          ? relation
          : Member.relationFromMemberNumber(memberNo),
      scheme: (j['scheme'] ?? j['Scheme'])?.toString(),
      active: active,
    );
  }
}
