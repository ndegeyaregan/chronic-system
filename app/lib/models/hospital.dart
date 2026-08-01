class Hospital {
  final String id;
  final String name;
  final String city;
  final String province;
  final String? address;
  final String? phone;
  final String? email;
  final String? type;
  final String? workingHours;
  final bool hasDirectBooking;
  final String? integrationType;
  final double? latitude;
  final double? longitude;
  final List<String> specialties;
  final List<String> conditionNames;

  const Hospital({
    required this.id,
    required this.name,
    required this.city,
    required this.province,
    this.address,
    this.phone,
    this.email,
    this.type,
    this.workingHours,
    this.hasDirectBooking = false,
    this.integrationType,
    this.latitude,
    this.longitude,
    this.specialties = const [],
    this.conditionNames = const [],
  });

  bool get isTmr => integrationType == 'tmr';

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        province: (json['province'] ?? '').toString(),
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        type: json['type'] as String?,
        workingHours: json['working_hours'] as String?,
        hasDirectBooking: (json['has_direct_booking'] ??
                json['hasDirectBooking'] ??
                json['direct_booking_capable'] ??
                false) as bool,
        integrationType: json['integration_type'] as String?,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        specialties: _parseStringList(json['specialties']),
        conditionNames: (json['conditions'] as List?)
                ?.map((e) =>
                    (e is Map ? (e['name'] ?? '') : e).toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
      );

  /// Maps a row from the `/institutions` endpoint (the admin-curated
  /// facility list also used by Facility Finder) onto this legacy model,
  /// since the old `/hospitals` endpoint reads from a table that's no
  /// longer kept in sync with admin add/suspend/delete actions.
  factory Hospital.fromInstitutionJson(Map<String, dynamic> json) {
    // Postgres NUMERIC columns (latitude/longitude) come back from
    // node-postgres as strings, not JSON numbers.
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Hospital(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      type: json['category'] as String?,
      workingHours: json['working_hours'] as String?,
      hasDirectBooking: (json['direct_booking_capable'] ?? false) as bool,
      latitude: toD(json['latitude']),
      longitude: toD(json['longitude']),
      specialties: _parseStringList(json['specialties']),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'province': province,
        'address': address,
        'phone': phone,
        'email': email,
        'type': type,
        'working_hours': workingHours,
        'has_direct_booking': hasDirectBooking,
        'latitude': latitude,
        'longitude': longitude,
        'specialties': specialties,
        'conditions': conditionNames.map((n) => {'name': n}).toList(),
      };
}
