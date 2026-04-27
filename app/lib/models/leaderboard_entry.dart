class LeaderboardEntry {
  final String memberId;
  final String memberName;
  final String memberNumber;
  final int totalPoints;
  final int fitnessPoints;
  final int workoutPoints;
  final int vitalPoints;
  final int medicationPoints;
  final int mealPoints;
  final int rank;
  final int? previousRank;

  const LeaderboardEntry({
    required this.memberId,
    required this.memberName,
    required this.memberNumber,
    required this.totalPoints,
    required this.fitnessPoints,
    required this.workoutPoints,
    required this.vitalPoints,
    required this.medicationPoints,
    required this.mealPoints,
    required this.rank,
    this.previousRank,
  });

  /// Trend: positive = moved up, negative = moved down, 0 = same
  int get rankChange => previousRank != null ? previousRank! - rank : 0;

  String get initials {
    final parts = memberName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M';
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        memberId: (json['member_id'] ?? json['memberId'] ?? '').toString(),
        memberName: (json['member_name'] ?? json['memberName'] ?? 'Member').toString(),
        memberNumber: (json['member_number'] ?? json['memberNumber'] ?? '').toString(),
        totalPoints: ((json['total_points'] ?? json['totalPoints'] ?? 0) as num).toInt(),
        fitnessPoints: ((json['fitness_points'] ?? json['fitnessPoints'] ?? 0) as num).toInt(),
        workoutPoints: ((json['workout_points'] ?? json['workoutPoints'] ?? 0) as num).toInt(),
        vitalPoints: ((json['vital_points'] ?? json['vitalPoints'] ?? 0) as num).toInt(),
        medicationPoints: ((json['medication_points'] ?? json['medicationPoints'] ?? 0) as num).toInt(),
        mealPoints: ((json['meal_points'] ?? json['mealPoints'] ?? 0) as num).toInt(),
        rank: ((json['rank'] ?? 0) as num).toInt(),
        previousRank: json['previous_rank'] != null
            ? (json['previous_rank'] as num).toInt()
            : null,
      );
}
