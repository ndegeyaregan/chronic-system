// Cycle tracker domain model.
//
// Stored locally on-device only (private health data). Each [CycleEntry]
// represents one menstrual period; predictions for the next cycle, fertile
// window and ovulation are derived in [CycleStats].

enum FlowLevel { spotting, light, medium, heavy }

extension FlowLevelX on FlowLevel {
  String get label {
    switch (this) {
      case FlowLevel.spotting:
        return 'Spotting';
      case FlowLevel.light:
        return 'Light';
      case FlowLevel.medium:
        return 'Medium';
      case FlowLevel.heavy:
        return 'Heavy';
    }
  }

  String get id => name;

  static FlowLevel fromId(String? id) {
    return FlowLevel.values.firstWhere(
      (f) => f.name == id,
      orElse: () => FlowLevel.medium,
    );
  }
}

class CycleEntry {
  final String id; // local uuid (timestamp-based)
  final DateTime startDate;
  final DateTime? endDate;
  final FlowLevel flow;
  final List<String> symptoms;
  final String? mood;
  final String? notes;

  const CycleEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    this.flow = FlowLevel.medium,
    this.symptoms = const [],
    this.mood,
    this.notes,
  });

  CycleEntry copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    FlowLevel? flow,
    List<String>? symptoms,
    String? mood,
    String? notes,
    bool clearMood = false,
    bool clearNotes = false,
  }) =>
      CycleEntry(
        id: id,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        flow: flow ?? this.flow,
        symptoms: symptoms ?? this.symptoms,
        mood: clearMood ? null : (mood ?? this.mood),
        notes: clearNotes ? null : (notes ?? this.notes),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'flow': flow.id,
        'symptoms': symptoms,
        'mood': mood,
        'notes': notes,
      };

  factory CycleEntry.fromJson(Map<String, dynamic> json) => CycleEntry(
        id: json['id'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] == null
            ? null
            : DateTime.parse(json['end_date'] as String),
        flow: FlowLevelX.fromId(json['flow'] as String?),
        symptoms: (json['symptoms'] as List?)?.cast<String>() ?? const [],
        mood: json['mood'] as String?,
        notes: json['notes'] as String?,
      );

  /// Duration (inclusive) in days, or null if still ongoing.
  int? get periodLengthDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays + 1;
  }
}

/// Common symptom suggestions surfaced as quick-pick chips.
const List<String> kCycleSymptomSuggestions = [
  'Cramps',
  'Headache',
  'Bloating',
  'Backache',
  'Fatigue',
  'Tender breasts',
  'Acne',
  'Nausea',
  'Cravings',
  'Mood swings',
  'Insomnia',
  'Spotting',
];

/// Mood quick-picks.
const List<String> kCycleMoodOptions = [
  '😊 Happy',
  '😌 Calm',
  '😐 Neutral',
  '😟 Anxious',
  '😢 Sad',
  '😡 Irritable',
  '🥱 Tired',
];

/// Aggregate statistics + predictions derived from a list of [CycleEntry]s.
class CycleStats {
  final int avgCycleLength;
  final int avgPeriodLength;
  final DateTime? lastPeriodStart;
  final DateTime? lastPeriodEnd;
  final DateTime? predictedNextStart;
  final DateTime? predictedNextEnd;
  final DateTime? predictedOvulation;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final bool isInPeriod;
  final int? currentCycleDay;
  final int? daysUntilNextPeriod;

  const CycleStats({
    this.avgCycleLength = 28,
    this.avgPeriodLength = 5,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.predictedNextStart,
    this.predictedNextEnd,
    this.predictedOvulation,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.isInPeriod = false,
    this.currentCycleDay,
    this.daysUntilNextPeriod,
  });

  factory CycleStats.from(List<CycleEntry> entries) {
    if (entries.isEmpty) return const CycleStats();
    final sorted = [...entries]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final last = sorted.last;

    // Average cycle length: take last up to 6 inter-start gaps.
    int avgCycle = 28;
    if (sorted.length >= 2) {
      final gaps = <int>[];
      for (var i = sorted.length - 1; i > 0 && gaps.length < 6; i--) {
        gaps.add(
          sorted[i].startDate.difference(sorted[i - 1].startDate).inDays,
        );
      }
      final reasonable = gaps.where((g) => g >= 18 && g <= 45).toList();
      if (reasonable.isNotEmpty) {
        avgCycle =
            (reasonable.reduce((a, b) => a + b) / reasonable.length).round();
      }
    }

    // Average period length: only entries with an explicit end date.
    int avgPeriod = 5;
    final closed = sorted.where((e) => e.endDate != null).toList();
    if (closed.isNotEmpty) {
      final tail = closed.length > 6 ? closed.sublist(closed.length - 6) : closed;
      final lens = tail.map((e) => e.periodLengthDays!).toList();
      avgPeriod = (lens.reduce((a, b) => a + b) / lens.length).round();
      if (avgPeriod < 2) avgPeriod = 2;
      if (avgPeriod > 10) avgPeriod = 10;
    }

    final today = _today();
    final lastStart = _dateOnly(last.startDate);
    final lastEnd = last.endDate != null ? _dateOnly(last.endDate!) : null;

    // Currently in period if today is between start and end (or within
    // avgPeriod days when end is still open).
    final ongoingEnd =
        lastEnd ?? lastStart.add(Duration(days: avgPeriod - 1));
    final isInPeriod = !today.isBefore(lastStart) && !today.isAfter(ongoingEnd);

    final predictedNextStart = lastStart.add(Duration(days: avgCycle));
    final predictedNextEnd =
        predictedNextStart.add(Duration(days: avgPeriod - 1));
    final predictedOvulation =
        predictedNextStart.subtract(const Duration(days: 14));
    final fertileStart = predictedOvulation.subtract(const Duration(days: 5));
    final fertileEnd = predictedOvulation.add(const Duration(days: 1));

    final cycleDay = today.difference(lastStart).inDays + 1;
    final daysUntilNext = predictedNextStart.difference(today).inDays;

    return CycleStats(
      avgCycleLength: avgCycle,
      avgPeriodLength: avgPeriod,
      lastPeriodStart: lastStart,
      lastPeriodEnd: lastEnd,
      predictedNextStart: predictedNextStart,
      predictedNextEnd: predictedNextEnd,
      predictedOvulation: predictedOvulation,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: fertileEnd,
      isInPeriod: isInPeriod,
      currentCycleDay: cycleDay > 0 ? cycleDay : null,
      daysUntilNextPeriod: daysUntilNext,
    );
  }

  bool isFertile(DateTime day) {
    if (fertileWindowStart == null || fertileWindowEnd == null) return false;
    final d = _dateOnly(day);
    return !d.isBefore(fertileWindowStart!) && !d.isAfter(fertileWindowEnd!);
  }

  bool isOvulation(DateTime day) {
    if (predictedOvulation == null) return false;
    return _dateOnly(day) == predictedOvulation;
  }

  bool isPredictedPeriod(DateTime day) {
    if (predictedNextStart == null || predictedNextEnd == null) return false;
    final d = _dateOnly(day);
    return !d.isBefore(predictedNextStart!) && !d.isAfter(predictedNextEnd!);
  }
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
