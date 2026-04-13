class Medication {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String? instructions;
  final String? nextDoseTime;
  final double adherencePercent;
  final bool isTakenToday;
  final bool isSkippedToday;
  final String? condition;
  final String? prescribedDate;
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? prescriptionUrl;
  final String? audioUrl;
  final String? videoUrl;
  final String? photoUrl;
  // Pharmacy & refill
  final String? pharmacyId;
  final String? pharmacyName;
  final String? pharmacyPhone;
  final int? refillIntervalDays;
  final String? nextRefillDate;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.instructions,
    this.nextDoseTime,
    this.adherencePercent = 0,
    this.isTakenToday = false,
    this.isSkippedToday = false,
    this.condition,
    this.prescribedDate,
    this.startDate,
    this.endDate,
    this.startTime,
    this.prescriptionUrl,
    this.audioUrl,
    this.videoUrl,
    this.photoUrl,
    this.pharmacyId,
    this.pharmacyName,
    this.pharmacyPhone,
    this.refillIntervalDays,
    this.nextRefillDate,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        dosage: (json['dosage'] ?? '').toString(),
        frequency: (json['frequency'] ?? '').toString(),
        instructions: json['instructions'] as String?,
        nextDoseTime:
            (json['next_dose_time'] ?? json['nextDoseTime']) as String?,
        adherencePercent: double.tryParse(
              (json['adherence_percent'] ??
                      json['adherencePercent'] ??
                      '0')
                  .toString()) ??
            0.0,
        isTakenToday:
            (json['is_taken_today'] ?? json['isTakenToday'] ?? false) as bool,
        isSkippedToday:
            (json['is_skipped_today'] ?? json['isSkippedToday'] ?? false)
                as bool,
        condition: json['condition'] as String?,
        prescribedDate:
            (json['prescribed_date'] ?? json['prescribedDate']) as String?,
        startDate: (json['start_date'] ?? json['startDate']) as String?,
        endDate: (json['end_date'] ?? json['endDate']) as String?,
        startTime: (json['start_time'] ?? json['startTime']) as String?,
        prescriptionUrl:
            (json['prescription_file_url'] ?? json['prescription_url'] ?? json['prescriptionUrl']) as String?,
        audioUrl: json['audio_url'] as String?,
        videoUrl: json['video_url'] as String?,
        photoUrl: json['photo_url'] as String?,
        pharmacyId: json['pharmacy_id'] as String?,
        pharmacyName: json['pharmacy_name'] as String?,
        pharmacyPhone: json['pharmacy_phone'] as String?,
        refillIntervalDays: json['refill_interval_days'] != null
            ? int.tryParse(json['refill_interval_days'].toString())
            : null,
        nextRefillDate: json['next_refill_date'] as String?,
      );

  /// True when the medication's end date is set and in the past.
  bool get isCompleted {
    if (endDate == null) return false;
    try {
      return DateTime.parse(endDate!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Days until next refill. Negative means overdue.
  int? get daysUntilRefill {
    if (nextRefillDate == null) return null;
    try {
      final refill = DateTime.parse(nextRefillDate!);
      return refill.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }

  /// True if refill is within 14 days (time to request authorization)
  bool get refillSoon {
    final d = daysUntilRefill;
    return d != null && d <= 14 && d >= 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'instructions': instructions,
        'next_dose_time': nextDoseTime,
        'adherence_percent': adherencePercent,
        'is_taken_today': isTakenToday,
        'is_skipped_today': isSkippedToday,
        'condition': condition,
        'prescribed_date': prescribedDate,
        'start_date': startDate,
        'end_date': endDate,
        'start_time': startTime,
        'prescription_url': prescriptionUrl,
        'audio_url': audioUrl,
        'video_url': videoUrl,
        'photo_url': photoUrl,
      };

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? frequency,
    String? instructions,
    String? nextDoseTime,
    double? adherencePercent,
    bool? isTakenToday,
    bool? isSkippedToday,
    String? condition,
    String? prescribedDate,
    String? startDate,
    String? endDate,
    String? startTime,
    String? prescriptionUrl,
    String? audioUrl,
    String? videoUrl,
    String? photoUrl,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        instructions: instructions ?? this.instructions,
        nextDoseTime: nextDoseTime ?? this.nextDoseTime,
        adherencePercent: adherencePercent ?? this.adherencePercent,
        isTakenToday: isTakenToday ?? this.isTakenToday,
        isSkippedToday: isSkippedToday ?? this.isSkippedToday,
        condition: condition ?? this.condition,
        prescribedDate: prescribedDate ?? this.prescribedDate,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        startTime: startTime ?? this.startTime,
        prescriptionUrl: prescriptionUrl ?? this.prescriptionUrl,
        audioUrl: audioUrl ?? this.audioUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

class DoseLog {
  final String id;
  final String medicationId;
  final DateTime takenAt;
  final String status;

  const DoseLog({
    required this.id,
    required this.medicationId,
    required this.takenAt,
    required this.status,
  });

  factory DoseLog.fromJson(Map<String, dynamic> json) => DoseLog(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        medicationId:
            (json['medication_id'] ?? json['medicationId'] ?? '').toString(),
        takenAt: DateTime.parse(
            (json['taken_at'] ?? json['takenAt'] ?? DateTime.now().toIso8601String())
                .toString()),
        status: (json['status'] ?? 'taken').toString(),
      );
}
