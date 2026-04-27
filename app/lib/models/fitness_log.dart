class FitnessLog {
  final String id;
  final String activityType;
  final int? steps;
  final int durationMinutes;
  final int? caloriesBurned;
  final DateTime loggedAt;
  final String? notes;

  const FitnessLog({
    required this.id,
    required this.activityType,
    this.steps,
    required this.durationMinutes,
    this.caloriesBurned,
    required this.loggedAt,
    this.notes,
  });

  factory FitnessLog.fromJson(Map<String, dynamic> json) => FitnessLog(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        activityType:
            (json['activity_type'] ?? json['activityType'] ?? 'walking')
                .toString(),
        steps: json['steps'] != null
            ? (json['steps'] as num).toInt()
            : null,
        durationMinutes:
            ((json['duration_minutes'] ?? json['durationMinutes'] ?? 0) as num)
                .toInt(),
        caloriesBurned: json['calories_burned'] != null
            ? (json['calories_burned'] as num).toInt()
            : json['caloriesBurned'] != null
                ? (json['caloriesBurned'] as num).toInt()
                : null,
        loggedAt: DateTime.parse(
            (json['logged_at'] ?? json['loggedAt'] ?? json['created_at'] ?? json['log_date'] ?? DateTime.now().toIso8601String())
                .toString()),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity_type': activityType,
        'steps': steps,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'logged_at': loggedAt.toIso8601String(),
        'notes': notes,
      };

  String get activityLabel {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 'Walking';
      case 'running':
        return 'Running';
      case 'cycling':
        return 'Cycling';
      case 'gym':
        return 'Gym Workout';
      case 'swimming':
        return 'Swimming';
      case 'rope_skipping':
        return 'Rope Skipping';
      default:
        return 'Activity';
    }
  }

  String get activityEmoji {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return '🚶';
      case 'running':
        return '🏃';
      case 'cycling':
        return '🚴';
      case 'gym':
        return '🏋️';
      case 'swimming':
        return '🏊';
      case 'rope_skipping':
        return '🪢';
      default:
        return '⚡';
    }
  }
}
