import 'member.dart';

double _toAmount(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '').trim();
  return double.tryParse(s) ?? 0;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  return s == 'yes' || s == 'y' || s == 'true' || s == '1';
}

/// Plan benefit allocations for a member (principal or dependant).
///
/// Maps directly to the Sanlam endpoints:
///  - GetPlanBenefitList -> [Benefit.fromJson]   (rows include name + memberNo)
///  - GetMemberPlanBenefit -> [Benefit.fromMyJson] (no name/memberNo in payload)
///
/// The API returns annual ALLOCATION amounts only; "used" / "remaining"
/// are derived elsewhere from claims (visits) history.
class Benefit {
  /// Internal Sanlam benefit row id (e.g. "82582").
  final String id;
  final String name;
  final String memberNo;
  final double outPatient;
  final double inPatient;
  final double dental;
  final double optical;
  final bool coPayActive;

  const Benefit({
    required this.id,
    required this.name,
    required this.memberNo,
    required this.outPatient,
    required this.inPatient,
    required this.dental,
    required this.optical,
    required this.coPayActive,
  });

  double get totalAllocation => outPatient + inPatient + dental + optical;

  /// GetMemberPlanBenefit: `{ id, outPatient, inPatient, dental, optical, coPayActive }`.
  /// Name and memberNo come from the authenticated [member] context.
  factory Benefit.fromMyJson(Map<String, dynamic> j, Member member) => Benefit(
        id: (j['id'] ?? j['Id'] ?? member.memberNumber).toString(),
        name: member.fullName,
        memberNo: member.memberNumber,
        outPatient: _toAmount(j['outPatient'] ?? j['OutPatient']),
        inPatient: _toAmount(j['inPatient'] ?? j['InPatient']),
        dental: _toAmount(j['dental'] ?? j['Dental']),
        optical: _toAmount(j['optical'] ?? j['Optical']),
        coPayActive: _toBool(j['coPayActive'] ?? j['CoPayActive']),
      );

  /// GetPlanBenefitList row:
  /// `{ id, name, memberNo, outPatient, inPatient, dental, optical, coPayActive }`.
  factory Benefit.fromJson(Map<String, dynamic> j) => Benefit(
        id: (j['id'] ?? j['Id'] ?? '').toString(),
        name: (j['name'] ?? j['Name'] ?? j['memberName'] ?? j['MemberName'] ?? '')
            .toString(),
        memberNo: (j['memberNo'] ?? j['MemberNo'] ?? '').toString(),
        outPatient: _toAmount(j['outPatient'] ?? j['OutPatient']),
        inPatient: _toAmount(j['inPatient'] ?? j['InPatient']),
        dental: _toAmount(j['dental'] ?? j['Dental']),
        optical: _toAmount(j['optical'] ?? j['Optical']),
        coPayActive: _toBool(j['coPayActive'] ?? j['CoPayActive']),
      );
}
