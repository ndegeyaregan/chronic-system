enum NotificationType {
  medication,
  appointment,
  vital,
  lifestyle,
  preauth,
  claim,
  general,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  /// Optional route to navigate to when tapped (e.g. '/home/preauths').
  final String? actionRoute;
  /// Optional entity ID for deep-link navigation (e.g. a preauth ID).
  final String? actionId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
    this.actionId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = _parseType((json['type'] ?? 'general').toString());
    final actionId = (json['action_id'] ?? json['actionId'] ?? '').toString().trim();
    // Prefer an explicit route from the API, fall back to type-based default.
    final rawRoute = (json['action_route'] ?? json['actionRoute'] ?? '').toString().trim();
    final actionRoute = rawRoute.isNotEmpty ? rawRoute : _defaultRoute(type);

    return AppNotification(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      type: type,
      createdAt: DateTime.parse(
          (json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String())
              .toString()),
      isRead: (json['is_read'] ?? json['isRead'] ?? false) as bool,
      actionRoute: actionRoute.isEmpty ? null : actionRoute,
      actionId: actionId.isEmpty ? null : actionId,
    );
  }

  static NotificationType _parseType(String s) {
    switch (s.toLowerCase()) {
      case 'medication':
        return NotificationType.medication;
      case 'appointment':
        return NotificationType.appointment;
      case 'vital':
        return NotificationType.vital;
      case 'lifestyle':
        return NotificationType.lifestyle;
      case 'preauth':
      case 'pre_auth':
      case 'pre-auth':
      case 'preauthorization':
        return NotificationType.preauth;
      case 'claim':
      case 'visit':
        return NotificationType.claim;
      default:
        return NotificationType.general;
    }
  }

  /// Default deep-link route per notification type.
  static String _defaultRoute(NotificationType t) {
    switch (t) {
      case NotificationType.medication:
        return '/home/medications';
      case NotificationType.appointment:
        return '/home/appointments';
      case NotificationType.vital:
        return '/home/vitals';
      case NotificationType.lifestyle:
        return '/home/lifestyle';
      case NotificationType.preauth:
        return '/home/preauths';
      case NotificationType.claim:
        return '/home/claims';
      case NotificationType.general:
        return '';
    }
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        actionRoute: actionRoute,
        actionId: actionId,
      );
}
