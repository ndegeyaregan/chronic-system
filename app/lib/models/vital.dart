class Vital {
  final String id;
  final double? bloodSugar;
  final int? systolicBP;
  final int? diastolicBP;
  final double? weight;
  final double? height; // cm
  final int? heartRate;
  final double? oxygenSaturation;
  final int? painLevel;
  final String? mood;
  final String? notes;
  final DateTime loggedAt;

  const Vital({
    required this.id,
    this.bloodSugar,
    this.systolicBP,
    this.diastolicBP,
    this.weight,
    this.height,
    this.heartRate,
    this.oxygenSaturation,
    this.painLevel,
    this.mood,
    this.notes,
    required this.loggedAt,
  });

  factory Vital.fromJson(Map<String, dynamic> json) => Vital(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        bloodSugar: _toDouble(json['blood_sugar_mmol'] ?? json['blood_sugar'] ?? json['bloodSugar']),
        systolicBP: _toInt(json['systolic_bp'] ?? json['systolicBP']),
        diastolicBP: _toInt(json['diastolic_bp'] ?? json['diastolicBP']),
        weight: _toDouble(json['weight_kg'] ?? json['weight']),
        height: _toDouble(json['height_cm'] ?? json['height']),
        heartRate: _toInt(json['heart_rate'] ?? json['heartRate']),
        oxygenSaturation: _toDouble(
            json['o2_saturation'] ?? json['oxygen_saturation'] ?? json['oxygenSaturation']),
        painLevel: _toInt(json['pain_level'] ?? json['painLevel']),
        mood: json['mood'] as String?,
        notes: json['notes'] as String?,
        loggedAt: DateTime.parse(
            (json['recorded_at'] ?? json['logged_at'] ?? json['loggedAt'] ?? DateTime.now().toIso8601String())
                .toString()),
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'blood_sugar': bloodSugar,
        'systolic_bp': systolicBP,
        'diastolic_bp': diastolicBP,
        'weight': weight,
        'height_cm': height,
        'heart_rate': heartRate,
        'oxygen_saturation': oxygenSaturation,
        'pain_level': painLevel,
        'mood': mood,
        'notes': notes,
        'logged_at': loggedAt.toIso8601String(),
      };

  String get bpString =>
      (systolicBP != null && diastolicBP != null)
          ? '$systolicBP/$diastolicBP mmHg'
          : '--';

  /// BMI using this record's weight and height (if both present).
  double? get bmi {
    if (weight == null || height == null || height! <= 0) return null;
    final hm = height! / 100.0;
    return weight! / (hm * hm);
  }

  bool get hasAnyReading =>
      bloodSugar != null ||
      systolicBP != null ||
      weight != null ||
      heartRate != null ||
      oxygenSaturation != null;
}
