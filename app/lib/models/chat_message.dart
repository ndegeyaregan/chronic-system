class ChatMessage {
  final int id;
  final String memberId;
  final String memberName;
  final String message;
  final bool isFromAdmin;
  final String? adminName;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.message,
    required this.isFromAdmin,
    this.adminName,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      memberId: json['member_id']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isFromAdmin: json['is_from_admin'] == true,
      adminName: json['admin_name']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}
