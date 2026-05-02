/// Categories used by the facility finder. These match the values stored
/// in the backend `category` column (and what the UI filter chips emit).
class InstitutionCategory {
  static const outpatient = 'outpatient';
  static const inpatient  = 'inpatient';
  static const pharmacy   = 'pharmacy';
  static const dental     = 'dental';
  static const optical    = 'optical';

  static const all = [outpatient, inpatient, pharmacy, dental, optical];

  static String label(String c) {
    switch (c) {
      case outpatient: return 'Outpatient';
      case inpatient:  return 'Inpatient';
      case pharmacy:   return 'Pharmacy';
      case dental:     return 'Dental';
      case optical:    return 'Optical';
      default: return c;
    }
  }
}

/// Map a Sanlam `mField` to one of the local categories.
String? mapMFieldToCategory(String? mField) {
  if (mField == null) return null;
  final v = mField.toLowerCase();
  if (v.contains('out-patient only')) return InstitutionCategory.outpatient;
  if (v.contains('in and out-patient')) return InstitutionCategory.inpatient;
  if (v.contains('pharmacy')) return InstitutionCategory.pharmacy;
  if (v.contains('dental')) return InstitutionCategory.dental;
  if (v.contains('optical')) return InstitutionCategory.optical;
  return null;
}

class Institution {
  final String id;            // backend UUID
  final String? sanlamId;     // upstream Sanlam id
  final String name;
  final String category;      // outpatient | inpatient | pharmacy | dental | optical
  final String? address;
  final String? street;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? title;
  final String? shortId;
  final double? latitude;
  final double? longitude;
  final List<String> specialties;
  final bool directBookingCapable;
  final bool isSuspended;
  final String? suspendedReason;
  final bool isDeleted;
  final bool isUserAdded;

  const Institution({
    required this.id,
    required this.name,
    required this.category,
    this.sanlamId,
    this.address,
    this.street,
    this.city,
    this.province,
    this.postalCode,
    this.phone,
    this.email,
    this.firstName,
    this.lastName,
    this.title,
    this.shortId,
    this.latitude,
    this.longitude,
    this.specialties = const [],
    this.directBookingCapable = false,
    this.isSuspended = false,
    this.suspendedReason,
    this.isDeleted = false,
    this.isUserAdded = false,
  });

  /// Build an [Institution] from a Sanlam `searchInstitution` row.
  /// Sanlam fields: id, name, firstName, lastName, tittle/title, email,
  /// street, address, city, postalCode, shortId, mField.
  factory Institution.fromSanlamJson(Map<String, dynamic> j) {
    final sid = (j['id'] ?? j['Id'] ?? '').toString();
    final mField = (j['mField'] ?? j['MField'] ?? '').toString();
    final cat = mapMFieldToCategory(mField) ?? '';
    return Institution(
      id: 'sanlam_$sid',
      sanlamId: sid,
      name: (j['name'] ?? j['Name'] ?? '').toString(),
      category: cat,
      address: j['address']?.toString(),
      street: j['street']?.toString(),
      city: j['city']?.toString(),
      postalCode: j['postalCode']?.toString(),
      email: j['email']?.toString(),
      firstName: j['firstName']?.toString(),
      lastName: j['lastName']?.toString(),
      title: (j['tittle'] ?? j['title'])?.toString(),
      shortId: j['shortId']?.toString(),
    );
  }

  factory Institution.fromBackendJson(Map<String, dynamic> j) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Institution(
      id: (j['id'] ?? '').toString(),
      sanlamId: j['sanlam_id']?.toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString().toLowerCase(),
      address: j['address']?.toString(),
      street: j['street']?.toString(),
      city: j['city']?.toString(),
      province: j['province']?.toString(),
      postalCode: j['postal_code']?.toString(),
      phone: j['phone']?.toString(),
      email: j['email']?.toString(),
      firstName: j['first_name']?.toString(),
      lastName: j['last_name']?.toString(),
      title: j['title']?.toString(),
      shortId: j['short_id']?.toString(),
      latitude: toD(j['latitude']),
      longitude: toD(j['longitude']),
      specialties: List<String>.from(
          (j['specialties'] as List?)?.map((e) => e.toString()) ?? []),
      directBookingCapable: (j['direct_booking_capable'] ?? false) as bool,
      isSuspended: (j['is_suspended'] ?? false) as bool,
      suspendedReason: j['suspended_reason']?.toString(),
      isDeleted: (j['is_deleted'] ?? false) as bool,
      isUserAdded: (j['is_user_added'] ?? false) as bool,
    );
  }

  String get contactName {
    final parts = [title, firstName, lastName]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.join(' ');
  }
}
