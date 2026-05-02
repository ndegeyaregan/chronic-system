/// Member-level co-pay assigned to a single institution.
/// Co-pay can be a fixed amount and/or a percentage; either may be null.
class CoPay {
  final String instId;       // matches Institution.sanlamId
  final String? shortId;
  final String institution;
  final String? benefitSchemes;

  final double? outPatient;       // UGX
  final double? outPatientPercent; // 0..100
  final double? outPatientMax;
  final double? inPatient;
  final double? inPatientPercent;
  final double? inPatientMax;
  final double? dental;
  final double? dentalPercent;
  final double? optical;
  final double? opticalPercent;

  const CoPay({
    required this.instId,
    required this.institution,
    this.shortId,
    this.benefitSchemes,
    this.outPatient,
    this.outPatientPercent,
    this.outPatientMax,
    this.inPatient,
    this.inPatientPercent,
    this.inPatientMax,
    this.dental,
    this.dentalPercent,
    this.optical,
    this.opticalPercent,
  });

  static double? _toD(dynamic v) {
    if (v == null) return null;
    final s = v.toString().replaceAll('%', '').trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  factory CoPay.fromJson(Map<String, dynamic> j) => CoPay(
        instId: (j['InstId'] ?? '').toString(),
        shortId: j['ShortId']?.toString(),
        institution: (j['Institution'] ?? '').toString(),
        benefitSchemes: j['Benefitschemes']?.toString(),
        outPatient: _toD(j['OutPatient']),
        outPatientPercent: _toD(j['OutPatientPer']),
        outPatientMax: _toD(j['OutPatientMax']),
        inPatient: _toD(j['InPatient']),
        inPatientPercent: _toD(j['InPatientPer']),
        inPatientMax: _toD(j['InPatientMax']),
        dental: _toD(j['Dental']),
        dentalPercent: _toD(j['DentalPer']),
        optical: _toD(j['Optical']),
        opticalPercent: _toD(j['OpticalPer']),
      );

  /// True iff at least one positive co-pay value is defined.
  bool get hasAnyCharge {
    bool pos(double? v) => v != null && v > 0;
    return pos(outPatient) ||
        pos(outPatientPercent) ||
        pos(inPatient) ||
        pos(inPatientPercent) ||
        pos(dental) ||
        pos(dentalPercent) ||
        pos(optical) ||
        pos(opticalPercent);
  }
}
