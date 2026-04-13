class Hospital {
  final String id;
  final String name;
  final String city;
  final String province;
  final String? address;
  final String? phone;
  final bool hasDirectBooking;
  final double? latitude;
  final double? longitude;
  final List<String> specialties;

  const Hospital({
    required this.id,
    required this.name,
    required this.city,
    required this.province,
    this.address,
    this.phone,
    this.hasDirectBooking = false,
    this.latitude,
    this.longitude,
    this.specialties = const [],
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        province: (json['province'] ?? '').toString(),
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        hasDirectBooking:
            (json['has_direct_booking'] ?? json['hasDirectBooking'] ?? json['direct_booking_capable'] ?? false)
                as bool,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        specialties: List<String>.from(
            (json['specialties'] as List?)?.map((e) => e.toString()) ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'province': province,
        'address': address,
        'phone': phone,
        'has_direct_booking': hasDirectBooking,
        'latitude': latitude,
        'longitude': longitude,
        'specialties': specialties,
      };
}
