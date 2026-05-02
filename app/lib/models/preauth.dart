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
  });

  /// Stable id used for routing. Falls back to authCode if claimNo missing.
  String get id => claimNo.isNotEmpty ? claimNo : authCode;

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

    return Preauth(
      claimNo: claimNo,
      memberNo: pick(['MemberNo', 'memberNo', 'member_no']),
      memberName: pick(['MemberName', 'memberName', 'member_name']),
      shortCode: pick(['SHORTCODE', 'shortCode', 'shortcode']),
      status: parsePreauthStatus(statusRaw),
      statusLabel: statusRaw.isEmpty ? 'Unknown' : statusRaw,
      diagnosis: pick(['diagnosis', 'Diagnosis']),
      symptoms: pick(['symptoms', 'Symptoms']),
      requestType: pick(['requestType', 'RequestType']),
      requestedAmount: parseAmount(j['requestedAmount'] ?? j['RequestedAmount']),
      approvedAmount: parseAmount(j['approvedAmount'] ?? j['ApprovedAmount']),
      description: pick(['description', 'Description']),
      insurerNote: pick(['insNote', 'InsNote', 'insurerNote']),
      authCode: pick(['authcode', 'authCode', 'AuthCode']),
      requestDate: _dateFromClaimNo(claimNo),
    );
  }
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
