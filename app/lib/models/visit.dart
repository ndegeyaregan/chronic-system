class Visit {
  final String visitId;
  final String claimNo;
  final String treatmentDate;
  final String institution;
  final String treatmentType;
  final String claimStatus;
  final double totalAmount;
  final int visitStatus;

  const Visit({
    required this.visitId,
    required this.claimNo,
    required this.treatmentDate,
    required this.institution,
    required this.treatmentType,
    required this.claimStatus,
    required this.totalAmount,
    required this.visitStatus,
  });

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        visitId: (j['visitId'] ?? j['VisitId'] ?? '').toString(),
        claimNo: (j['claimNo'] ?? j['ClaimNo'] ?? '').toString(),
        treatmentDate:
            (j['treatmentDate'] ?? j['TreatmentDate'] ?? '').toString(),
        institution: (j['institution'] ?? j['Institution'] ?? '').toString(),
        treatmentType:
            (j['treatmentType'] ?? j['TreatmentType'] ?? '').toString(),
        claimStatus: (j['claimStatus'] ?? j['ClaimStatus'] ?? '').toString(),
        totalAmount:
            double.tryParse(j['totalAmount']?.toString() ?? '0') ?? 0,
        visitStatus: int.tryParse(j['visitStatus']?.toString() ?? '0') ?? 0,
      );

  /// Tolerant parser: accepts ISO 8601, "yyyy-MM-dd[ HH:mm[:ss]]",
  /// "dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy" and similar.
  DateTime? get treatmentDateParsed => parseFlexibleDate(treatmentDate);
}

DateTime? parseFlexibleDate(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  // Sanlam format: "28 Apr 2026 | 00:00" or "28 Apr 2026" — strip the time half.
  if (s.contains('|')) s = s.split('|').first.trim();

  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  final spaceFix = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (spaceFix != null) return spaceFix;

  // "28 Apr 2026" / "28 April 2026" / "Apr 28 2026" / "28-Apr-2026"
  const monthAbbr = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10,
    'november': 11, 'december': 12,
  };
  final tokens = s
      .replaceAll(RegExp(r'[,\-/]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.length >= 3) {
    int? day, month, year;
    for (final t in tokens) {
      final lower = t.toLowerCase();
      if (monthAbbr.containsKey(lower)) {
        month ??= monthAbbr[lower];
      } else {
        final n = int.tryParse(t);
        if (n != null) {
          if (n >= 1900) {
            year ??= n;
          } else if (day == null && n >= 1 && n <= 31) {
            day = n;
          } else if (year == null && n < 100) {
            year = 2000 + n;
          }
        }
      }
    }
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  final m = RegExp(r'^(\d{1,4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,4})').firstMatch(s);
  if (m != null) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);
    int y, mo, d;
    if (a > 31) {
      y = a; mo = b; d = c;
    } else if (c > 31) {
      y = c;
      if (a > 12) { d = a; mo = b; } else { d = a; mo = b; }
    } else {
      return null;
    }
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }
  return null;
}
