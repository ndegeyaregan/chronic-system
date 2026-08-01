enum AppointmentStatus { pending, confirmed, cancelled, completed, missed }

class Appointment {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final String? hospitalCity;
  final String? hospitalPhone;
  final String? hospitalAddress;
  final String condition;
  final DateTime appointmentDate;
  final String preferredTime;
  final String reason;
  final AppointmentStatus status;
  final String? notes;
  final String? missedReason;
  final DateTime? confirmedDate;
  final String? confirmedTime;
  final bool isDirectBooked;

  const Appointment({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    this.hospitalCity,
    this.hospitalPhone,
    this.hospitalAddress,
    required this.condition,
    required this.appointmentDate,
    required this.preferredTime,
    required this.reason,
    required this.status,
    this.notes,
    this.missedReason,
    this.confirmedDate,
    this.confirmedTime,
    this.isDirectBooked = false,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        hospitalId: (json['hospital_id'] ?? json['hospitalId'] ?? '').toString(),
        hospitalName:
            (json['hospital_name'] ?? json['hospitalName'] ?? '').toString(),
        hospitalCity:
            (json['hospital_city'] ?? json['hospitalCity']) as String?,
        hospitalPhone:
            (json['hospital_phone'] ?? json['hospitalPhone']) as String?,
        hospitalAddress:
            (json['hospital_address'] ?? json['hospitalAddress']) as String?,
        condition:
            (json['condition'] ?? json['condition_name'] ?? '').toString(),
        appointmentDate: DateTime.parse(
            (json['appointment_date'] ??
                    json['appointmentDate'] ??
                    DateTime.now().toIso8601String())
                .toString()),
        preferredTime:
            (json['preferred_time'] ?? json['preferredTime'] ?? '08:00')
                .toString(),
        reason: (json['reason'] ?? '').toString(),
        status: _parseStatus((json['status'] ?? 'pending').toString()),
        notes: json['notes'] as String?,
        missedReason: json['missed_reason'] as String?,
        confirmedDate: json['confirmed_date'] != null
            ? DateTime.tryParse(json['confirmed_date'].toString())
            : null,
        confirmedTime:
            (json['confirmed_time'] ?? json['confirmedTime']) as String?,
        isDirectBooked:
            (json['is_direct_booked'] ?? json['isDirectBooked'] ?? false)
                as bool,
      );

  static AppointmentStatus _parseStatus(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'completed':
        return AppointmentStatus.completed;
      case 'missed':
        return AppointmentStatus.missed;
      default:
        return AppointmentStatus.pending;
    }
  }

  Appointment copyWith({
    AppointmentStatus? status,
    String? missedReason,
    bool clearMissedReason = false,
  }) =>
      Appointment(
        id: id,
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        hospitalCity: hospitalCity,
        hospitalPhone: hospitalPhone,
        hospitalAddress: hospitalAddress,
        condition: condition,
        appointmentDate: appointmentDate,
        preferredTime: preferredTime,
        reason: reason,
        status: status ?? this.status,
        notes: notes,
        missedReason:
            clearMissedReason ? null : (missedReason ?? this.missedReason),
        confirmedDate: confirmedDate,
        confirmedTime: confirmedTime,
        isDirectBooked: isDirectBooked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospital_id': hospitalId,
        'hospital_name': hospitalName,
        'hospital_city': hospitalCity,
        'hospital_phone': hospitalPhone,
        'hospital_address': hospitalAddress,
        'condition': condition,
        'appointment_date': appointmentDate.toIso8601String(),
        'preferred_time': preferredTime,
        'reason': reason,
        'status': status.toString().split('.').last,
        'notes': notes,
        'missed_reason': missedReason,
        'confirmed_date': confirmedDate?.toIso8601String(),
        'confirmed_time': confirmedTime,
        'is_direct_booked': isDirectBooked,
      };

  bool get isUpcoming =>
      appointmentDate.isAfter(DateTime.now()) &&
      status != AppointmentStatus.cancelled;

  bool get isPast =>
      appointmentDate.isBefore(DateTime.now()) ||
      status == AppointmentStatus.completed ||
      status == AppointmentStatus.cancelled ||
      status == AppointmentStatus.missed;

  bool get needsConfirmation =>
      appointmentDate.isBefore(DateTime.now()) &&
      (status == AppointmentStatus.pending ||
          status == AppointmentStatus.confirmed);
}
