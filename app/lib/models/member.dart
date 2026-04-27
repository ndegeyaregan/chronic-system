class Member {
  final String id;
  final String memberNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? dateOfBirth;
  final String planType;
  final List<String> conditions;
  final bool isPasswordSet;

  const Member({
    required this.id,
    required this.memberNumber,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.dateOfBirth,
    required this.planType,
    required this.conditions,
    required this.isPasswordSet,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        memberNumber:
            (json['member_number'] ?? json['memberNumber'] ?? '').toString(),
        firstName:
            (json['first_name'] ?? json['firstName'] ?? '').toString(),
        lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        dateOfBirth:
            (json['date_of_birth'] ?? json['dateOfBirth']) as String?,
        planType: (json['plan_type'] ?? json['planType'] ?? 'Standard')
            .toString(),
        conditions: ((json['conditions'] as List?) ?? [])
            .where((c) => c != null)
            .map<String>((c) => c is Map ? (c['name'] ?? '').toString() : c.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
        isPasswordSet:
            (json['is_password_set'] ?? json['isPasswordSet'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_number': memberNumber,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth,
        'plan_type': planType,
        'conditions': conditions,
        'is_password_set': isPasswordSet,
      };

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '${f.toUpperCase()}${l.toUpperCase()}';
  }

  Member copyWith({
    String? id,
    String? memberNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? planType,
    List<String>? conditions,
    bool? isPasswordSet,
  }) =>
      Member(
        id: id ?? this.id,
        memberNumber: memberNumber ?? this.memberNumber,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        planType: planType ?? this.planType,
        conditions: conditions ?? this.conditions,
        isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      );
}
