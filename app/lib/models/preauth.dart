/// Status values returned by the Sanlam pre-auth endpoint.
///
/// API uses: `Open | Approved | Rejected | Pending | Cancelled`.
/// We treat `Pending` as `open` for filtering purposes.
enum PreauthStatus { open, approved, rejected, cancelled, unknown }

extension PreauthStatusX on PreauthStatus {
  String get label {
    switch (this) {
      case PreauthStatus.open:
        return 'Open';
      case PreauthStatus.approved:
        return 'Approved';
      case PreauthStatus.rejected:
        return 'Rejected';
      case PreauthStatus.cancelled:
        return 'Cancelled';
      case PreauthStatus.unknown:
        return 'Unknown';
    }
  }

  /// Value to send back to the Sanlam API in the `Status` filter param.
  String get apiValue {
    switch (this) {
      case PreauthStatus.open:
        return 'Open';
      case PreauthStatus.approved:
        return 'Approved';
      case PreauthStatus.rejected:
        return 'Rejected';
      case PreauthStatus.cancelled:
        return 'Cancelled';
      case PreauthStatus.unknown:
        return '';
    }
  }
}

PreauthStatus parsePreauthStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'open':
    case 'pending':
      return PreauthStatus.open;
    case 'approved':
      return PreauthStatus.approved;
    case 'rejected':
    case 'declined':
      return PreauthStatus.rejected;
    case 'cancelled':
    case 'canceled':
      return PreauthStatus.cancelled;
    default:
      return PreauthStatus.unknown;
  }
}

class Preauth {
  /// Unique reference, e.g. `PRHE-260428-127`.
  final String claimNo;
  final String memberNo;
  final String memberName;
  final String shortCode;
  final PreauthStatus status;
  final String statusLabel;
  final String diagnosis;
  final String symptoms;

  /// Raw request type from the API: `OUT | IN | DENTAL | OPTICAL | OUTPATIENT | ...`.
  final String requestType;

  final double requestedAmount;
  final double approvedAmount;

  /// Service requested (the user-facing description).
  final String description;

  /// Insurer note (e.g. "Approved up to UGX 400,000"). Empty if none.
  final String insurerNote;

  final String authCode;

  /// Best-effort request/decision date. Sanlam's payload doesn't include a
  /// timestamp, but the `claimNo` embeds one (`SHORTCODE-YYMMDD-seq`), which
  /// we parse here.
  final DateTime? requestDate;

  /// When the pre-auth was first submitted (from `createdAt`).
  /// Used to start the turnaround-time clock on the Pre-Auth screen.
  final DateTime? createdAt;

  /// When the pre-auth was last updated (from `updatedAt`).
  /// Used to stop the turnaround-time clock once a decision is made.
  final DateTime? updatedAt;

  const Preauth({
    required this.claimNo,
    required this.memberNo,
    required this.memberName,
    required this.shortCode,
    required this.status,
    required this.statusLabel,
    required this.diagnosis,
    required this.symptoms,
    required this.requestType,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.description,
    required this.insurerNote,
    required this.authCode,
    required this.requestDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Stable id used for routing. Falls back to authCode if claimNo missing.
  String get id => claimNo.isNotEmpty ? claimNo : authCode;

  /// Turnaround time:
  ///  - For Open requests → time elapsed since [createdAt] until now (live).
  ///  - For decided (Approved/Rejected) → fixed duration from [createdAt]
  ///    to [updatedAt].
  /// Returns null if we can't compute it from the available timestamps.
  Duration? turnaroundDuration({DateTime? now}) {
    final start = createdAt;
    if (start == null) return null;
    if (status == PreauthStatus.open) {
      return (now ?? DateTime.now()).difference(start);
    }
    final end = updatedAt;
    if (end == null) return null;
    return end.difference(start);
  }

  /// Normalised request-type bucket: out / in / dental / optical / other.
  String get requestTypeBucket {
    final u = requestType.toUpperCase();
    if (u.contains('DENTAL')) return 'dental';
    if (u.contains('OPTICAL')) return 'optical';
    if (u.contains('OUT')) return 'outpatient';
    if (u.contains('IN')) return 'inpatient';
    return 'other';
  }

  /// True when the request was decided (not still open) within the last
  /// [withinDays]. Used to highlight "new" approvals/rejections.
  bool isRecent({int withinDays = 14, DateTime? now}) {
    final d = requestDate;
    if (d == null) return false;
    if (status == PreauthStatus.open) return false;
    final today = now ?? DateTime.now();
    return today.difference(d).inDays.abs() <= withinDays;
  }

  factory Preauth.fromJson(Map<String, dynamic> j) {
    double parseAmount(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '').trim();
      return double.tryParse(s) ?? 0;
    }

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    final claimNo = pick(['claimNo', 'ClaimNo', 'claim_no']);
    final statusRaw = pick(['Status', 'status']);
    final createdAt = _parseSanlamDateTime(pick(['createdAt', 'CreatedAt']));
    final updatedAt = _parseSanlamDateTime(pick(['updatedAt', 'UpdatedAt']));

    return Preauth(
      claimNo: claimNo,
      memberNo: pick(['MemberNo', 'memberNo', 'member_no']),
      memberName: pick(['MemberName', 'memberName', 'member_name']),
      shortCode: pick(['SHORTCODE', 'shortCode', 'shortcode']),
      status: parsePreauthStatus(statusRaw),
      statusLabel: statusRaw.isEmpty ? 'Unknown' : statusRaw,
      diagnosis: pick(['diagnosis', 'Diagnosis']),
      symptoms: pick(['symptoms', 'Symptoms']),
      requestType: pick(['requestType', 'RequestType', 'treatmentType', 'TreatmentType']),
      requestedAmount: parseAmount(j['requestedAmount'] ?? j['RequestedAmount']),
      approvedAmount: parseAmount(j['approvedAmount'] ?? j['ApprovedAmount']),
      description: pick(['description', 'Description']),
      insurerNote: pick(['insNote', 'InsNote', 'insurerNote']),
      authCode: pick(['authcode', 'authCode', 'AuthCode']),
      requestDate: createdAt ?? _dateFromClaimNo(claimNo),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Parses Sanlam-format date-time strings such as
/// `"03/02/2026 8:09:30 PM"` (DD/MM/YYYY h:mm:ss AM/PM).
/// Falls back to ISO parsing if the format doesn't match.
DateTime? _parseSanlamDateTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final m = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    var hour = int.parse(m.group(4)!);
    final minute = int.parse(m.group(5)!);
    final second = int.tryParse(m.group(6) ?? '0') ?? 0;
    final ampm = m.group(7)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return DateTime(year, month, day, hour, minute, second);
  }
  return DateTime.tryParse(s);
}

/// Sanlam claim numbers follow `SHORTCODE-YYMMDD-seq`, e.g. `PRHE-260428-127`.
DateTime? _dateFromClaimNo(String claimNo) {
  final m = RegExp(r'-(\d{6})-').firstMatch(claimNo);
  if (m == null) return null;
  final s = m.group(1)!;
  final yy = int.tryParse(s.substring(0, 2));
  final mm = int.tryParse(s.substring(2, 4));
  final dd = int.tryParse(s.substring(4, 6));
  if (yy == null || mm == null || dd == null) return null;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  // 2-digit year: assume 2000s window (00-79 => 20xx, 80-99 => 19xx).
  final year = yy < 80 ? 2000 + yy : 1900 + yy;
  return DateTime(year, mm, dd);
}
