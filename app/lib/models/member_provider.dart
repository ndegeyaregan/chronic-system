class MemberProvider {
  final String id;
  final String memberId;
  final String providerType; // doctor | hospital | both
  final String? doctorName;
  final String? doctorContact;
  final String? doctorEmail;
  final String? hospitalId;
  final String? hospitalName;
  final String? hospitalAddress;
  final String? notes;
  final DateTime createdAt;

  MemberProvider({
    required this.id,
    required this.memberId,
    required this.providerType,
    this.doctorName,
    this.doctorContact,
    this.doctorEmail,
    this.hospitalId,
    this.hospitalName,
    this.hospitalAddress,
    this.notes,
    required this.createdAt,
  });

  factory MemberProvider.fromJson(Map<String, dynamic> json) {
    return MemberProvider(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      providerType: json['provider_type'] as String,
      doctorName: json['doctor_name'] as String?,
      doctorContact: json['doctor_contact'] as String?,
      doctorEmail: json['doctor_email'] as String?,
      hospitalId: json['hospital_id'] as String?,
      hospitalName: json['hospital_name'] ?? json['hospital_db_name'] as String?,
      hospitalAddress: json['hospital_address'] ?? json['hospital_db_address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get hasDoctor => providerType == 'doctor' || providerType == 'both';
  bool get hasHospital => providerType == 'hospital' || providerType == 'both';
}
