enum NotificationType { medication, appointment, vital, lifestyle, general }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? json['body'] ?? '').toString(),
        type: _parseType((json['type'] ?? 'general').toString()),
        createdAt: DateTime.parse(
            (json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String())
                .toString()),
        isRead: (json['is_read'] ?? json['isRead'] ?? false) as bool,
      );

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
      default:
        return NotificationType.general;
    }
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );
}
