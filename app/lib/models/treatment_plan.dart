class TreatmentPlan {
  final String id;
  final String memberId;
  final String? title;
  final String? description;
  final String? documentUrl;
  final String? photoUrl;
  final String? audioUrl;
  final String? videoUrl;
  final double? cost;
  final String currency;
  final DateTime? planDate;
  final String? providerName;
  final String? conditionId;
  final String? conditionName;
  final String status; // active | completed | cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  TreatmentPlan({
    required this.id,
    required this.memberId,
    this.title,
    this.description,
    this.documentUrl,
    this.photoUrl,
    this.audioUrl,
    this.videoUrl,
    this.cost,
    this.currency = 'UGX',
    this.planDate,
    this.providerName,
    this.conditionId,
    this.conditionName,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory TreatmentPlan.fromJson(Map<String, dynamic> json) {
    return TreatmentPlan(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      documentUrl: json['document_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      videoUrl: json['video_url'] as String?,
      cost: json['cost'] != null ? double.tryParse(json['cost'].toString()) : null,
      currency: json['currency'] as String? ?? 'UGX',
      planDate: json['plan_date'] != null ? DateTime.tryParse(json['plan_date'].toString()) : null,
      providerName: json['provider_name'] as String?,
      conditionId: json['condition_id'] as String?,
      conditionName: json['condition_name'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get hasMedia => photoUrl != null || audioUrl != null || videoUrl != null || documentUrl != null;

  String get formattedCost {
    if (cost == null) return 'Not specified';
    return '$currency ${cost!.toStringAsFixed(0)}';
  }

  String get formattedDate {
    if (planDate == null) return 'Not specified';
    return '${planDate!.day}/${planDate!.month}/${planDate!.year}';
  }
}
