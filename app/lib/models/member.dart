import 'dart:convert';

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
  final String? schemeName;
  final String? planCode;
  final bool isChronic;
  final String? relation;
  final bool isPrincipal;
  final String? mobile;
  final String? profileIcon;
  final String? accessToken;
  final int? tokenExp;

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
    this.schemeName,
    this.planCode,
    this.isChronic = false,
    this.relation,
    this.isPrincipal = false,
    this.mobile,
    this.profileIcon,
    this.accessToken,
    this.tokenExp,
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
        schemeName: json['scheme_name'] as String? ?? json['schemeName'] as String?,
        planCode: json['plan_code'] as String? ?? json['planCode'] as String?,
        isChronic: (json['is_chronic'] ?? json['isChronic'] ?? false) as bool,
        relation: json['relation'] as String?,
        isPrincipal: (json['is_principal'] ?? json['isPrincipal'] ?? false) as bool,
        mobile: json['mobile'] as String?,
        profileIcon: json['profile_picture_url'] as String? ??
            json['profile_icon'] as String? ??
            json['profileIcon'] as String?,
        accessToken: json['access_token'] as String? ?? json['accessToken'] as String?,
        tokenExp: json['token_exp'] as int? ?? json['tokenExp'] as int?,
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
        'scheme_name': schemeName,
        'plan_code': planCode,
        'is_chronic': isChronic,
        'relation': relation,
        'is_principal': isPrincipal,
        'mobile': mobile,
        'profile_icon': profileIcon,
        'access_token': accessToken,
        'token_exp': tokenExp,
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
    String? schemeName,
    String? planCode,
    bool? isChronic,
    String? relation,
    bool? isPrincipal,
    String? mobile,
    String? profileIcon,
    bool clearProfileIcon = false,
    String? accessToken,
    int? tokenExp,
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
        schemeName: schemeName ?? this.schemeName,
        planCode: planCode ?? this.planCode,
        isChronic: isChronic ?? this.isChronic,
        relation: relation ?? this.relation,
        isPrincipal: isPrincipal ?? this.isPrincipal,
        mobile: mobile ?? this.mobile,
        profileIcon: clearProfileIcon ? null : (profileIcon ?? this.profileIcon),
        accessToken: accessToken ?? this.accessToken,
        tokenExp: tokenExp ?? this.tokenExp,
      );

  static String relationFromMemberNumber(String mn) {
    final suffix = mn.split('-').last;
    if (suffix == '00') return 'Principal';
    if (suffix == '01') return 'Spouse';
    return 'Dependant';
  }

  factory Member.fromSanlamLogin(Map<String, dynamic> json) {
    final memberNo = (json['memberNo'] ?? '').toString();
    final memberName = (json['memberName'] ?? '').toString();
    final parts = memberName.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : memberName;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final accessToken = (json['accessToken'] ?? '').toString();
    int? tokenExp;
    if (accessToken.isNotEmpty) {
      try {
        final jwtParts = accessToken.split('.');
        if (jwtParts.length == 3) {
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(jwtParts[1]))),
          ) as Map<String, dynamic>;
          tokenExp = payload['exp'] as int?;
        }
      } catch (_) {}
    }

    final isPrincipalRaw = json['isPrincipal'];
    final isPrincipal = isPrincipalRaw == true ||
        isPrincipalRaw.toString().toLowerCase() == 'true';

    final relation = (json['relation'] as String?)?.isNotEmpty == true
        ? json['relation'] as String
        : (memberNo.isNotEmpty ? Member.relationFromMemberNumber(memberNo) : null);

    return Member(
      id: memberNo,
      memberNumber: memberNo,
      firstName: firstName,
      lastName: lastName,
      email: json['email'] as String?,
      mobile: (json['mobile'] as String?),
      planType: 'Standard',
      conditions: const [],
      isPasswordSet: true,
      schemeName: (json['scheme'] as String?)?.trim().isNotEmpty == true
          ? (json['scheme'] as String).trim()
          : (json['schemeName'] as String?)?.trim(),
      planCode: json['planCode'] as String? ?? json['plan_code'] as String?,
      relation: relation,
      isPrincipal: isPrincipal,
      accessToken: accessToken.isNotEmpty ? accessToken : null,
      tokenExp: tokenExp,
      isChronic: false,
      profileIcon: json['profileIcon'] as String?,
    );
  }
}
