class Pharmacy {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? phone;
  final bool isActive;

  const Pharmacy({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.phone,
    this.isActive = true,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        address: json['address'] as String?,
        city: json['city'] as String?,
        phone: json['phone'] as String?,
        isActive: (json['is_active'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'phone': phone,
        'is_active': isActive,
      };
}
