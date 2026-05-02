/// A medication prescription dispensed (or pending dispense) at a pharmacy.
///
/// Maps to the Sanlam endpoint `GetPriscriptions` (yes, the upstream
/// spelling is "Pris..."). The payload may arrive as a single object or a
/// list — both are handled at the service layer.
class Prescription {
  final String memberNo;
  final String memberName;
  final String claimNo;
  final String issuedClaimNo;
  final String medication;
  final String prescribedBy;
  final String dosage;
  final int qty;
  final int issuedQty;
  final bool issued;
  final String category;
  final String code;

  const Prescription({
    required this.memberNo,
    required this.memberName,
    required this.claimNo,
    required this.issuedClaimNo,
    required this.medication,
    required this.prescribedBy,
    required this.dosage,
    required this.qty,
    required this.issuedQty,
    required this.issued,
    required this.category,
    required this.code,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == 'yes' || s == 'y' || s == 'true' || s == '1';
  }

  static String _s(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v != null) return v.toString();
    }
    return '';
  }

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        memberNo: _s(j, ['memberNo', 'MemberNo']),
        memberName: _s(j, ['memberName', 'MemberName']),
        claimNo: _s(j, ['claimNo', 'ClaimNo']),
        issuedClaimNo: _s(j, ['issuedclaimNo', 'issuedClaimNo', 'IssuedClaimNo']),
        medication: _s(j, ['medication', 'Medication']),
        prescribedBy: _s(j, ['prescribedBy', 'PrescribedBy']),
        dosage: _s(j, ['dosage', 'Dosage']),
        qty: _toInt(j['qty'] ?? j['Qty']),
        issuedQty: _toInt(j['isssuedQty'] ?? j['issuedQty'] ?? j['IssuedQty']),
        issued: _toBool(j['issued'] ?? j['Issued']),
        category: _s(j, ['category', 'Category']),
        code: _s(j, ['code', 'Code']),
      );

  /// True when none of the prescribed quantity has been dispensed yet.
  bool get isPending => !issued && issuedQty <= 0;

  /// True when some — but not all — of the quantity has been dispensed.
  bool get isPartiallyIssued => issuedQty > 0 && issuedQty < qty;

  /// True when the full prescribed quantity has been dispensed.
  bool get isFullyIssued => issued || (qty > 0 && issuedQty >= qty);
}
