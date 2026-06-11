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
  final double? pharma;
  final double? pharmaPercent;

  /// Pipe-separated employer/scheme names this co-pay applies to (whitelist).
  /// Only present on the institution co-pay (`GetInstCoPay`) endpoint.
  final String? coPayFor;

  /// Comma-separated scheme names that are excluded from this co-pay.
  /// Only present on the institution co-pay (`GetInstCoPay`) endpoint.
  final String? excludedSchemes;

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
    this.pharma,
    this.pharmaPercent,
    this.coPayFor,
    this.excludedSchemes,
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
        pharma: _toD(j['Pharma']),
        pharmaPercent: _toD(j['PharmaPer']),
        coPayFor: j['CoPay_for']?.toString(),
        excludedSchemes: j['ExcludedSchemes']?.toString(),
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
        pos(opticalPercent) ||
        pos(pharma) ||
        pos(pharmaPercent);
  }

  /// Returns true if this co-pay does NOT apply to a member on [schemeName].
  /// Honours the `ExcludedSchemes` blacklist (case-insensitive substring match).
  bool isExcludedFor(String? schemeName) {
    if (schemeName == null || schemeName.isEmpty) return false;
    final ex = (excludedSchemes ?? '').trim();
    if (ex.isEmpty) return false;
    final needle = schemeName.toLowerCase();
    return ex
        .split(RegExp(r'[,;|]'))
        .map((s) => s.trim().toLowerCase())
        .any((s) => s.isNotEmpty && (s == needle || needle.contains(s)));
  }
}
