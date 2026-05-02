import '../models/benefit.dart';
import '../models/visit.dart';

/// How urgent a forecast is.
enum ForecastSeverity {
  /// Will deplete before year-end.
  critical,

  /// Will deplete soon after year-end or utilisation already > 75%.
  watch,

  /// Healthy pace.
  onTrack,

  /// No spend yet — nothing meaningful to forecast.
  noActivity,
}

class CategoryForecast {
  final String category;
  final double allocation;
  final double ytdSpend;
  final double monthlyBurn;
  final double remaining;

  /// Whole months of runway left at the current burn rate. `null` when burn is 0.
  final double? monthsRemaining;

  /// Projected calendar date the allocation runs out. `null` when burn is 0.
  final DateTime? depletionDate;

  /// True when the allocation depletes on or before 31-Dec of the current year.
  final bool depletesThisYear;

  final ForecastSeverity severity;

  const CategoryForecast({
    required this.category,
    required this.allocation,
    required this.ytdSpend,
    required this.monthlyBurn,
    required this.remaining,
    required this.monthsRemaining,
    required this.depletionDate,
    required this.depletesThisYear,
    required this.severity,
  });

  double get utilisationRatio =>
      allocation <= 0 ? 0 : (ytdSpend / allocation).clamp(0.0, 1.0);
}

class BenefitAdvice {
  final ForecastSeverity overallSeverity;
  final CategoryForecast overall;
  final List<CategoryForecast> byCategory;

  /// Plain-English headline (e.g. "Outpatient runs out in Aug 2026").
  final String headline;

  /// Actionable recommendation tailored to the trend.
  final String recommendation;

  const BenefitAdvice({
    required this.overallSeverity,
    required this.overall,
    required this.byCategory,
    required this.headline,
    required this.recommendation,
  });

  /// Categories that will deplete before year-end, hardest-hit first.
  List<CategoryForecast> get atRiskCategories => byCategory
      .where((c) => c.severity == ForecastSeverity.critical)
      .toList()
    ..sort((a, b) {
      final ad = a.depletionDate;
      final bd = b.depletionDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
}

/// Top-level entry point: build a full advice payload from a member's
/// allocations and their YTD claim history.
///
/// [now] is overridable for tests.
BenefitAdvice buildBenefitAdvice({
  required Benefit benefit,
  required List<Visit> visits,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final ytdVisits = _ytdVisits(visits, today);

  CategoryForecast forecast(String label, double allocation,
      bool Function(String) match) {
    final spend = ytdVisits
        .where((v) => match(v.treatmentType))
        .fold<double>(0, (a, v) => a + v.totalAmount);
    return _buildForecast(
      category: label,
      allocation: allocation,
      ytdSpend: spend,
      now: today,
    );
  }

  final categories = <CategoryForecast>[
    forecast('Outpatient', benefit.outPatient, isOutPatient),
    forecast('Inpatient', benefit.inPatient, isInPatient),
    forecast('Dental', benefit.dental, isDental),
    forecast('Optical', benefit.optical, isOptical),
  ];

  final totalSpend =
      ytdVisits.fold<double>(0, (a, v) => a + v.totalAmount);
  final overall = _buildForecast(
    category: 'Overall',
    allocation: benefit.totalAllocation,
    ytdSpend: totalSpend,
    now: today,
  );

  final headline = _buildHeadline(overall, categories, today);
  final recommendation =
      _buildRecommendation(overall, categories, benefit.coPayActive);

  return BenefitAdvice(
    overallSeverity: overall.severity,
    overall: overall,
    byCategory: categories,
    headline: headline,
    recommendation: recommendation,
  );
}

CategoryForecast _buildForecast({
  required String category,
  required double allocation,
  required double ytdSpend,
  required DateTime now,
}) {
  final remaining = (allocation - ytdSpend).clamp(0, double.infinity).toDouble();
  final elapsedDays = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  final elapsedMonths = elapsedDays / (365.0 / 12.0);
  final monthlyBurn = elapsedMonths <= 0 ? 0.0 : ytdSpend / elapsedMonths;

  double? monthsRemaining;
  DateTime? depletionDate;
  if (monthlyBurn > 0 && remaining > 0) {
    monthsRemaining = remaining / monthlyBurn;
    final daysOut = (monthsRemaining * (365.0 / 12.0)).round();
    depletionDate = now.add(Duration(days: daysOut));
  } else if (monthlyBurn > 0 && remaining <= 0) {
    monthsRemaining = 0;
    depletionDate = now;
  }

  final endOfYear = DateTime(now.year, 12, 31);
  final depletesThisYear =
      depletionDate != null && !depletionDate.isAfter(endOfYear);

  ForecastSeverity severity;
  if (allocation <= 0 || ytdSpend <= 0) {
    severity = ForecastSeverity.noActivity;
  } else if (remaining <= 0) {
    severity = ForecastSeverity.critical;
  } else if (depletesThisYear) {
    severity = ForecastSeverity.critical;
  } else {
    final util = ytdSpend / allocation;
    severity =
        util >= 0.6 ? ForecastSeverity.watch : ForecastSeverity.onTrack;
  }

  return CategoryForecast(
    category: category,
    allocation: allocation,
    ytdSpend: ytdSpend,
    monthlyBurn: monthlyBurn,
    remaining: remaining,
    monthsRemaining: monthsRemaining,
    depletionDate: depletionDate,
    depletesThisYear: depletesThisYear,
    severity: severity,
  );
}

String _buildHeadline(CategoryForecast overall,
    List<CategoryForecast> categories, DateTime now) {
  if (overall.severity == ForecastSeverity.noActivity) {
    return 'No claims yet this year — your full allocation is available.';
  }

  final critical = categories
      .where((c) => c.severity == ForecastSeverity.critical)
      .toList();

  if (overall.severity == ForecastSeverity.critical) {
    final when = overall.depletionDate;
    if (when == null || overall.remaining <= 0) {
      return 'Your overall benefit is fully utilised.';
    }
    return 'At your current pace your overall benefit runs out around '
        '${_monthYear(when)}.';
  }

  if (critical.isNotEmpty) {
    final c = critical.first;
    final when = c.depletionDate;
    return when == null
        ? '${c.category} cover is fully utilised.'
        : '${c.category} cover is on track to run out around ${_monthYear(when)}.';
  }

  if (overall.severity == ForecastSeverity.watch) {
    return 'You\'re using your benefits faster than average — '
        'still on track for the year.';
  }

  return 'You\'re well within your benefit limits for the year.';
}

String _buildRecommendation(CategoryForecast overall,
    List<CategoryForecast> categories, bool coPayActive) {
  final critical = categories
      .where((c) => c.severity == ForecastSeverity.critical)
      .toList();

  if (overall.severity == ForecastSeverity.noActivity) {
    return 'Use scheduled check-ups and chronic-care visits early in the year '
        'to stay ahead of complications.';
  }

  if (overall.severity == ForecastSeverity.critical) {
    return 'Speak to your care manager about pre-authorising upcoming visits, '
        'switching to in-network providers, and prioritising essential care '
        'for the rest of the year.';
  }

  if (critical.isNotEmpty) {
    final names = critical.map((c) => c.category.toLowerCase()).join(' and ');
    return 'Watch your $names spending — consider in-network providers and '
        'pre-authorisation to stretch the remaining cover.';
  }

  if (overall.severity == ForecastSeverity.watch) {
    return coPayActive
        ? 'Co-payments apply on this plan — using in-network providers will '
            'help keep out-of-pocket costs down.'
        : 'Keep visits within network providers and stick to your treatment '
            'plan to stay on pace.';
  }

  return 'Keep up regular preventive visits — they help avoid costly '
      'inpatient claims later in the year.';
}

// ─────────────────────────────────────────────────────────────────────────────
// Category matchers (kept here so other screens can reuse the same logic).
// ─────────────────────────────────────────────────────────────────────────────

bool isOutPatient(String t) => t.toUpperCase().contains('OUT');
bool isDental(String t) => t.toUpperCase().contains('DENTAL');
bool isOptical(String t) => t.toUpperCase().contains('OPTICAL');
bool isInPatient(String t) {
  final u = t.toUpperCase();
  return u.contains('IN') &&
      !u.contains('OUT') &&
      !isDental(t) &&
      !isOptical(t);
}

List<Visit> _ytdVisits(List<Visit> visits, DateTime now) {
  return visits.where((v) {
    final d = v.treatmentDateParsed;
    return d != null && d.year == now.year && !d.isAfter(now);
  }).toList();
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
