class MemberProviderModel {
  final String id;
  final String providerType; // doctor, hospital, both
  final String? doctorName;
  final String? doctorContact;
  final String? hospitalName;
  final String? hospitalAddress;
  final String? notes;

  const MemberProviderModel({
    required this.id,
    required this.providerType,
    this.doctorName,
    this.doctorContact,
    this.hospitalName,
    this.hospitalAddress,
    this.notes,
  });

  factory MemberProviderModel.fromJson(Map<String, dynamic> json) {
    return MemberProviderModel(
      id: json['id']?.toString() ?? '',
      providerType: json['provider_type'] ?? 'doctor',
      doctorName: json['doctor_name'],
      doctorContact: json['doctor_contact'],
      hospitalName: json['hospital_name'],
      hospitalAddress: json['hospital_address'],
      notes: json['notes'],
    );
  }

  MemberProviderModel copyWith({
    String? providerType,
    String? doctorName,
    String? doctorContact,
    String? hospitalName,
    String? hospitalAddress,
    String? notes,
  }) =>
      MemberProviderModel(
        id: id,
        providerType: providerType ?? this.providerType,
        doctorName: doctorName ?? this.doctorName,
        doctorContact: doctorContact ?? this.doctorContact,
        hospitalName: hospitalName ?? this.hospitalName,
        hospitalAddress: hospitalAddress ?? this.hospitalAddress,
        notes: notes ?? this.notes,
      );
}
