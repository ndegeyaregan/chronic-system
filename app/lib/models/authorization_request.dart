enum AuthRequestType { medicationRefill, procedure, surgery, followUp }

enum AuthRequestStatus { pending, approved, rejected, cancelled }

class AuthorizationRequest {
  final String id;
  final String memberId;
  final AuthRequestType requestType;
  final String providerType; // 'pharmacy' | 'hospital'
  final String? providerId;
  final String? providerName;
  final DateTime? scheduledDate;
  final String? notes;
  final AuthRequestStatus status;
  final String? adminComments;
  final String? memberMedicationId;
  final String? treatmentPlanId;
  final String? medicationName;
  final String? treatmentPlanTitle;
  final DateTime createdAt;

  const AuthorizationRequest({
    required this.id,
    required this.memberId,
    required this.requestType,
    required this.providerType,
    this.providerId,
    this.providerName,
    this.scheduledDate,
    this.notes,
    required this.status,
    this.adminComments,
    this.memberMedicationId,
    this.treatmentPlanId,
    this.medicationName,
    this.treatmentPlanTitle,
    required this.createdAt,
  });

  factory AuthorizationRequest.fromJson(Map<String, dynamic> json) =>
      AuthorizationRequest(
        id: (json['id'] ?? '').toString(),
        memberId: (json['member_id'] ?? '').toString(),
        requestType: _parseType((json['request_type'] ?? '').toString()),
        providerType: (json['provider_type'] ?? 'pharmacy').toString(),
        providerId: json['provider_id'] as String?,
        providerName: json['provider_name'] as String?,
        scheduledDate: json['scheduled_date'] != null
            ? DateTime.tryParse(json['scheduled_date'].toString())
            : null,
        notes: json['notes'] as String?,
        status: _parseStatus((json['status'] ?? 'pending').toString()),
        adminComments: json['admin_comments'] as String?,
        memberMedicationId: json['member_medication_id'] as String?,
        treatmentPlanId: json['treatment_plan_id'] as String?,
        medicationName: json['medication_name'] as String?,
        treatmentPlanTitle: json['treatment_plan_title'] as String?,
        createdAt: DateTime.tryParse(
                (json['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );

  static AuthRequestType _parseType(String s) {
    switch (s) {
      case 'procedure':
        return AuthRequestType.procedure;
      case 'surgery':
        return AuthRequestType.surgery;
      case 'follow_up':
        return AuthRequestType.followUp;
      default:
        return AuthRequestType.medicationRefill;
    }
  }

  static AuthRequestStatus _parseStatus(String s) {
    switch (s) {
      case 'approved':
        return AuthRequestStatus.approved;
      case 'rejected':
        return AuthRequestStatus.rejected;
      case 'cancelled':
        return AuthRequestStatus.cancelled;
      default:
        return AuthRequestStatus.pending;
    }
  }

  String get requestTypeLabel {
    switch (requestType) {
      case AuthRequestType.procedure:
        return 'Procedure';
      case AuthRequestType.surgery:
        return 'Surgery';
      case AuthRequestType.followUp:
        return 'Follow-Up';
      default:
        return 'Medication Refill';
    }
  }

  Map<String, dynamic> toJsonMap() => {
        'id': id,
        'member_id': memberId,
        'request_type': requestType.name,
        'provider_type': providerType,
        'provider_id': providerId,
        'provider_name': providerName,
        'scheduled_date': scheduledDate?.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'admin_comments': adminComments,
        'member_medication_id': memberMedicationId,
        'treatment_plan_id': treatmentPlanId,
        'medication_name': medicationName,
        'treatment_plan_title': treatmentPlanTitle,
        'created_at': createdAt.toIso8601String(),
      };
}
