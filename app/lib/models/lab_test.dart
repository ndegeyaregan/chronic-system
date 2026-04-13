class LabTest {
  final String id;
  final String memberId;
  final String testType; // liver_function | kidney_function
  final DateTime? scheduledDate;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? resultFileUrl;
  final String? resultNotes;
  final String status; // pending | completed | overdue
  final bool alertSent;
  final DateTime createdAt;

  LabTest({
    required this.id,
    required this.memberId,
    required this.testType,
    this.scheduledDate,
    required this.dueDate,
    this.completedAt,
    this.resultFileUrl,
    this.resultNotes,
    this.status = 'pending',
    this.alertSent = false,
    required this.createdAt,
  });

  factory LabTest.fromJson(Map<String, dynamic> json) {
    return LabTest(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      testType: json['test_type'] as String,
      scheduledDate: json['scheduled_date'] != null ? DateTime.tryParse(json['scheduled_date'].toString()) : null,
      dueDate: DateTime.parse(json['due_date'] as String),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      resultFileUrl: json['result_file_url'] as String?,
      resultNotes: json['result_notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      alertSent: json['alert_sent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get testTypeLabel {
    switch (testType) {
      case 'liver_function':
        return 'Liver Function Test (LFT)';
      case 'kidney_function':
        return 'Kidney Function Test (KFT)';
      default:
        return testType;
    }
  }

  String get testTypeShort {
    switch (testType) {
      case 'liver_function':
        return 'LFT';
      case 'kidney_function':
        return 'KFT';
      default:
        return testType.toUpperCase();
    }
  }

  bool get isOverdue => status == 'pending' && dueDate.isBefore(DateTime.now());
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' && !isOverdue;

  String get formattedDueDate => '${dueDate.day}/${dueDate.month}/${dueDate.year}';
}
