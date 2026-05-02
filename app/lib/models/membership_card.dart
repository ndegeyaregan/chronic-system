import 'member.dart';

class MembershipCard {
  final String memberNo;
  final String memberName;
  final String schemeName;
  final String planCode;
  final String relation;

  const MembershipCard({
    required this.memberNo,
    required this.memberName,
    required this.schemeName,
    required this.planCode,
    required this.relation,
  });

  factory MembershipCard.fromMember(Member m) => MembershipCard(
        memberNo: m.memberNumber,
        memberName: m.fullName,
        schemeName: m.schemeName ?? 'Sanlam Medical Scheme',
        planCode: m.planCode ?? '',
        relation: m.relation ?? Member.relationFromMemberNumber(m.memberNumber),
      );
}
