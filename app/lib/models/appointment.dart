enum AppointmentStatus { pending, confirmed, cancelled, completed, missed }

class Appointment {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final String? hospitalCity;
  final String condition;
  final DateTime appointmentDate;
  final String preferredTime;
  final String reason;
  final AppointmentStatus status;
  final String? notes;
  final String? missedReason;

  const Appointment({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    this.hospitalCity,
    required this.condition,
    required this.appointmentDate,
    required this.preferredTime,
    required this.reason,
    required this.status,
    this.notes,
    this.missedReason,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        hospitalId:
            (json['hospital_id'] ?? json['hospitalId'] ?? '').toString(),
        hospitalName:
            (json['hospital_name'] ?? json['hospitalName'] ?? '').toString(),
        hospitalCity:
            (json['hospital_city'] ?? json['hospitalCity']) as String?,
        condition: (json['condition'] ?? json['condition_name'] ?? '').toString(),
        appointmentDate: DateTime.parse(
            (json['appointment_date'] ?? json['appointmentDate'] ?? DateTime.now().toIso8601String())
                .toString()),
        preferredTime:
            (json['preferred_time'] ?? json['preferredTime'] ?? '08:00')
                .toString(),
        reason: (json['reason'] ?? '').toString(),
        status: _parseStatus(
            (json['status'] ?? 'pending').toString()),
        notes: json['notes'] as String?,
        missedReason: json['missed_reason'] as String?,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospital_id': hospitalId,
        'hospital_name': hospitalName,
        'hospital_city': hospitalCity,
        'condition': condition,
        'appointment_date': appointmentDate.toIso8601String(),
        'preferred_time': preferredTime,
        'reason': reason,
        'status': status.toString().split('.').last,
        'notes': notes,
        'missed_reason': missedReason,
      };

  bool get isUpcoming =>
      appointmentDate.isAfter(DateTime.now()) &&
      status != AppointmentStatus.cancelled;

  bool get isPast =>
      appointmentDate.isBefore(DateTime.now()) ||
      status == AppointmentStatus.completed ||
      status == AppointmentStatus.cancelled ||
      status == AppointmentStatus.missed;

  // True if date has passed but user hasn't confirmed yet
  bool get needsConfirmation =>
      appointmentDate.isBefore(DateTime.now()) &&
      (status == AppointmentStatus.pending ||
          status == AppointmentStatus.confirmed);
}
