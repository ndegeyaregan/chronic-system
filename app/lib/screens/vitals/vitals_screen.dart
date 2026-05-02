import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/member_type_provider.dart';
import '../../providers/cycle_tracker_provider.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/loading_shimmer.dart';

class VitalsScreen extends ConsumerStatefulWidget {
  const VitalsScreen({super.key});

  @override
  ConsumerState<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends ConsumerState<VitalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _selectedMetric = 'Blood Sugar';

  static const _bg     = Color(0xFFF2F4F8);
  static const _text1  = Color(0xFF0D1117);
  static const _text2  = Color(0xFF6B7280);
  static const _blue   = Color(0xFF007AFF);
  static const _green  = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red    = Color(0xFFFF3B30);
  static const _teal   = Color(0xFF32ADE6);
  static const _divider = Color(0xFFE5E7EB);

  static const Map<String, Color> _metricColors = {
    'Blood Sugar':     _blue,
    'Blood Pressure':  _red,
    'Heart Rate':      _orange,
    'Weight':          _green,
    'O\u2082 Saturation': _teal,
  };

  final _metrics = ['Blood Sugar', 'Blood Pressure', 'Heart Rate', 'Weight', 'O\u2082 Saturation'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vitalsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
            ),
          ),
        ),
        title: const Text('Health Vitals',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () => context.push(routeVitalsHistory),
            tooltip: 'History',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart_rounded, size: 20), text: 'Vitals'),
            Tab(icon: Icon(Icons.check_circle_rounded, size: 20), text: 'Check-in'),
            Tab(icon: Icon(Icons.mood_rounded, size: 20), text: 'Mood'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(routeLogVitals),
        backgroundColor: _blue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log Vitals',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 3,
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _VitalsTab(
            state: state,
            selectedMetric: _selectedMetric,
            onMetricChange: (m) => setState(() => _selectedMetric = m),
            metrics: _metrics,
            metricColors: _metricColors,
          ),
          _DailyCheckInTab(state: state),
          _MoodHistoryTab(state: state),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VITALS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _VitalsTab extends ConsumerWidget {
  final VitalsState state;
  final String selectedMetric;
  final ValueChanged<String> onMetricChange;
  final List<String> metrics;
  final Map<String, Color> metricColors;

  static const _bg     = Color(0xFFF2F4F8);
  static const _text1  = Color(0xFF0D1117);
  static const _text2  = Color(0xFF6B7280);
  static const _blue   = Color(0xFF007AFF);
  static const _divider = Color(0xFFE5E7EB);

  const _VitalsTab({
    required this.state,
    required this.selectedMetric,
    required this.onMetricChange,
    required this.metrics,
    required this.metricColors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = ref.watch(memberProvider).member?.conditions ?? [];
    final isChronic = ref.watch(isChronicMemberProvider);
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingListCard(count: 4),
      );
    }

    final latest = state.latest;
    final total  = state.vitals.length;
    final lastN  = state.getLastNDays(7).length;

    return RefreshIndicator(
      color: _blue,
      onRefresh: () =>
          ProviderScope.containerOf(context)
              .read(vitalsProvider.notifier)
              .fetchVitals(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary strip ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  _summaryChip(Icons.bar_chart_rounded, '$total', 'Total readings', _blue),
                  _vDivider(),
                  _summaryChip(Icons.calendar_today_rounded, '$lastN', 'This week', const Color(0xFF34C759)),
                  _vDivider(),
                  _summaryChip(Icons.access_time_rounded,
                    latest != null ? DateFormat('d MMM').format(latest.loggedAt) : '—',
                    'Last logged', const Color(0xFFFF9500)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Cycle tracker (opt-in) ───────────────────────────────────
            const _CycleTrackerEntryCard(),

            if (latest == null)
              _emptyState()
            else ...[
              // ── Latest readings ──────────────────────────────────────────
              _sectionLabel('Latest Readings'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  if (latest.bloodSugar != null)
                    MetricCard(
                      label: 'Blood Sugar',
                      value: latest.bloodSugar!.toStringAsFixed(1),
                      unit: 'mmol/L',
                      icon: Icons.water_drop_rounded,
                      color: _blue,
                      isAlert: latest.bloodSugar! > 10 || latest.bloodSugar! < 3.9,
                      trend: latest.bloodSugar! > 7 ? 'up' : 'normal',
                    ),
                  if (latest.systolicBP != null)
                    MetricCard(
                      label: 'Blood Pressure',
                      value: '${latest.systolicBP}/${latest.diastolicBP}',
                      unit: 'mmHg',
                      icon: Icons.monitor_heart_rounded,
                      color: const Color(0xFFFF3B30),
                      isAlert: latest.systolicBP! > 140,
                      trend: latest.systolicBP! > 140 ? 'up' : 'normal',
                    ),
                  if (latest.heartRate != null)
                    MetricCard(
                      label: 'Heart Rate',
                      value: '${latest.heartRate}',
                      unit: 'bpm',
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFFF9500),
                      isAlert: latest.heartRate! > 100 || latest.heartRate! < 60,
                      trend: latest.heartRate! > 100 ? 'up' : 'normal',
                    ),
                  if (latest.weight != null)
                    MetricCard(
                      label: 'Weight',
                      value: latest.weight!.toStringAsFixed(1),
                      unit: 'kg',
                      icon: Icons.monitor_weight_rounded,
                      color: const Color(0xFF34C759),
                    ),
                  if (latest.oxygenSaturation != null)
                    MetricCard(
                      label: 'O\u2082 Saturation',
                      value: '${latest.oxygenSaturation!.toInt()}',
                      unit: '%',
                      icon: Icons.air_rounded,
                      color: const Color(0xFF32ADE6),
                      isAlert: latest.oxygenSaturation! < 94,
                    ),
                  // BMI card — uses latest weight + most recent logged height
                  Builder(builder: (_) {
                    final bmi = state.latestBmi;
                    if (bmi == null) return const SizedBox.shrink();
                    final (label, color) = _bmiCategory(bmi);
                    return MetricCard(
                      label: 'BMI',
                      value: bmi.toStringAsFixed(1),
                      unit: label,
                      icon: Icons.accessibility_new_rounded,
                      color: color,
                      isAlert: bmi < 18.5 || bmi >= 30,
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),

              // ── Trend chart ───────────────────────────────────────────────
              _sectionLabel('14-Day Trend'),
              const SizedBox(height: 10),
              // Metric chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: metrics.map((m) {
                    final col = metricColors[m]!;
                    final sel = selectedMetric == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onMetricChange(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? col : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? col : _divider),
                            boxShadow: sel ? [BoxShadow(color: col.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sel ? Colors.white : col,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(m,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _text1,
                                )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _buildChart(state, selectedMetric, metricColors[selectedMetric]!, conditions),
              const SizedBox(height: 16),
              _buildTrendInsight(state, selectedMetric, conditions),
              const SizedBox(height: 12),
              isChronic
                  ? _ChronicVitalsRec()
                  : _WellnessVitalsRec(),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns (category label, color) for a given BMI value.
  static (String, Color) _bmiCategory(double bmi) {
    if (bmi < 18.5) return ('Underweight', Color(0xFF3B82F6));
    if (bmi < 25.0) return ('Normal', Color(0xFF22C55E));
    if (bmi < 30.0) return ('Overweight', Color(0xFFF59E0B));
    return ('Obese', Color(0xFFEF4444));
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _text1, height: 1)),
          Text(label, style: const TextStyle(fontSize: 10, color: _text2)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 44, color: const Color(0xFFE5E7EB));

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text1, letterSpacing: -0.2));

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
    ),
    child: Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withValues(alpha: 0.08)),
          child: const Icon(Icons.monitor_heart_rounded, color: _blue, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('No vitals logged yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text1)),
        const SizedBox(height: 6),
        const Text('Tap "Log Vitals" below to record your first reading.',
          style: TextStyle(fontSize: 13, color: _text2), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildChart(VitalsState state, String metric, Color color, List<String> conditions) {
    final data = state.getLastNDays(14).reversed.toList();
    if (data.isEmpty) {
      return _chartEmpty('Not enough data for chart');
    }

    final hasHypertension = conditions.any((c) =>
        c.toLowerCase().contains('hypertension') ||
        c.toLowerCase().contains('high blood pressure'));
    final hasDiabetes = conditions.any((c) => c.toLowerCase().contains('diabetes'));

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      double? val;
      switch (metric) {
        case 'Blood Sugar':       val = data[i].bloodSugar; break;
        case 'Blood Pressure':    val = data[i].systolicBP?.toDouble(); break;
        case 'Heart Rate':        val = data[i].heartRate?.toDouble(); break;
        case 'Weight':            val = data[i].weight; break;
        case 'O\u2082 Saturation': val = data[i].oxygenSaturation; break;
      }
      if (val != null) spots.add(FlSpot(i.toDouble(), val));
    }

    if (spots.isEmpty) return _chartEmpty('No $metric data available');

    // ── Target / reference lines ─────────────────────────────────────────
    final extraLines = <HorizontalLine>[];
    if (metric == 'Blood Sugar') {
      final target = hasDiabetes ? 7.0 : 5.6;
      extraLines.add(HorizontalLine(
        y: target,
        color: const Color(0xFFF59E0B),
        strokeWidth: 1.5,
        dashArray: [5, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => hasDiabetes ? 'Target 7.0' : 'Target 5.6',
          style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
        ),
      ));
    } else if (metric == 'Blood Pressure') {
      final target = hasHypertension ? 130.0 : 140.0;
      extraLines.add(HorizontalLine(
        y: target,
        color: const Color(0xFFF59E0B),
        strokeWidth: 1.5,
        dashArray: [5, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => hasHypertension ? 'Target 130' : 'Target 140',
          style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
        ),
      ));
    } else if (metric == 'Heart Rate') {
      extraLines.add(HorizontalLine(
        y: 60,
        color: const Color(0xFF10B981),
        strokeWidth: 1.2,
        dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topLeft,
          labelResolver: (_) => 'Min 60',
          style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
        ),
      ));
      extraLines.add(HorizontalLine(
        y: 100,
        color: const Color(0xFF10B981),
        strokeWidth: 1.2,
        dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => 'Max 100',
          style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
        ),
      ));
    }

    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: LineChart(
        LineChartData(
          extraLinesData: ExtraLinesData(horizontalLines: extraLines),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: _divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: _text2)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return Text(DateFormat('d/M').format(data[idx].loggedAt),
                    style: const TextStyle(fontSize: 10, color: _text2));
                },
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: color,
                  strokeColor: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendInsight(VitalsState state, String metric, List<String> conditions) {
    final recent7 = state.getLastNDays(7);
    final prior14 = state.getLastNDays(14);
    final prior7 = prior14.where((v) {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return v.loggedAt.isBefore(cutoff);
    }).toList();

    double? extractVal(dynamic v) {
      switch (metric) {
        case 'Blood Sugar':       return v.bloodSugar;
        case 'Blood Pressure':    return v.systolicBP?.toDouble();
        case 'Heart Rate':        return v.heartRate?.toDouble();
        case 'Weight':            return v.weight;
        case 'O\u2082 Saturation': return v.oxygenSaturation;
        default: return null;
      }
    }

    final recentVals = recent7.map(extractVal).whereType<double>().toList();
    final priorVals  = prior7.map(extractVal).whereType<double>().toList();

    if (recentVals.isEmpty) return const SizedBox();

    final avgRecent = recentVals.reduce((a, b) => a + b) / recentVals.length;
    final avgPrior  = priorVals.isNotEmpty
        ? priorVals.reduce((a, b) => a + b) / priorVals.length
        : null;

    final hasHypertension = conditions.any((c) =>
        c.toLowerCase().contains('hypertension') ||
        c.toLowerCase().contains('high blood pressure'));
    final hasDiabetes = conditions.any((c) => c.toLowerCase().contains('diabetes'));

    // Target values
    double? target;
    String unit = '';
    String specificMsg = '';
    if (metric == 'Blood Sugar') {
      target = hasDiabetes ? 7.0 : 5.6;
      unit = 'mmol/L';
      if (avgRecent > target) {
        specificMsg = hasDiabetes
            ? 'This is above your diabetic target of ${target.toStringAsFixed(1)} mmol/L. Review your diet and medication with your doctor.'
            : 'This is above the normal target of ${target.toStringAsFixed(1)} mmol/L. Consider reducing sugar intake.';
      } else {
        specificMsg = 'Your blood sugar is within the target range. Keep it up!';
      }
    } else if (metric == 'Blood Pressure') {
      target = hasHypertension ? 130.0 : 140.0;
      unit = 'mmHg';
      if (avgRecent > target) {
        specificMsg = hasHypertension
            ? 'This is above your hypertension target of ${target.toInt()} mmHg. Consider reviewing your medication.'
            : 'Elevated above normal target of ${target.toInt()} mmHg. Monitor closely and reduce salt intake.';
      } else {
        specificMsg = 'Your blood pressure is well within the target. Excellent!';
      }
    } else if (metric == 'Heart Rate') {
      unit = 'bpm';
      if (avgRecent < 60) {
        specificMsg = 'Your average heart rate is below the normal range of 60–100 bpm. Inform your doctor.';
      } else if (avgRecent > 100) {
        specificMsg = 'Your average heart rate is above the normal range of 60–100 bpm. Seek medical advice.';
      } else {
        specificMsg = 'Your heart rate is in the normal range of 60–100 bpm. Well done!';
      }
    } else if (metric == 'Weight') {
      unit = 'kg';
      specificMsg = avgPrior != null
          ? (avgRecent > avgPrior
              ? 'Your weight has increased compared to the prior week. Monitor your diet.'
              : avgRecent < avgPrior
                  ? 'Your weight has decreased compared to the prior week.'
                  : 'Your weight has been stable this week.')
          : 'Keep tracking your weight to see trends over time.';
    } else if (metric == 'O\u2082 Saturation') {
      unit = '%';
      if (avgRecent < 94) {
        specificMsg = 'Your oxygen saturation is below 94%. Seek medical advice promptly.';
      } else if (avgRecent < 97) {
        specificMsg = 'Your O₂ saturation is acceptable but slightly below optimal (≥97%). Monitor closely.';
      } else {
        specificMsg = 'Your oxygen saturation is excellent! Keep up your breathing exercises.';
      }
    }

    // Trend direction
    String trendEmoji;
    String trendLabel;
    Color trendColor;
    if (avgPrior != null) {
      final diff = avgRecent - avgPrior;
      final threshold = avgPrior * 0.02; // 2% change threshold
      if (diff > threshold) {
        trendEmoji = '📈';
        trendLabel = 'Trending up';
        trendColor = (metric == 'Blood Sugar' || metric == 'Blood Pressure')
            ? const Color(0xFFEF4444)
            : (metric == 'O\u2082 Saturation' || metric == 'Heart Rate')
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B);
      } else if (diff < -threshold) {
        trendEmoji = '📉';
        trendLabel = 'Trending down';
        trendColor = (metric == 'Blood Sugar' || metric == 'Blood Pressure')
            ? const Color(0xFF10B981)
            : (metric == 'O\u2082 Saturation')
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B);
      } else {
        trendEmoji = '➡️';
        trendLabel = 'Stable';
        trendColor = const Color(0xFF10B981);
      }
    } else {
      trendEmoji = '➡️';
      trendLabel = 'Stable';
      trendColor = const Color(0xFF10B981);
    }

    // Overall status color for the card
    Color cardColor;
    if (metric == 'Blood Sugar' && target != null) {
      if (avgRecent > target * 1.1) { cardColor = const Color(0xFFEF4444); }
      else if (avgRecent > target) { cardColor = const Color(0xFFF59E0B); }
      else { cardColor = const Color(0xFF10B981); }
    } else if (metric == 'Blood Pressure' && target != null) {
      if (avgRecent > target + 20) { cardColor = const Color(0xFFEF4444); }
      else if (avgRecent > target) { cardColor = const Color(0xFFF59E0B); }
      else { cardColor = const Color(0xFF10B981); }
    } else if (metric == 'O\u2082 Saturation') {
      cardColor = avgRecent < 94
          ? const Color(0xFFEF4444)
          : avgRecent < 97
              ? const Color(0xFFF59E0B)
              : const Color(0xFF10B981);
    } else {
      cardColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trendEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Trend Insight',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cardColor)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$trendEmoji $trendLabel',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: trendColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '7-day avg: ${avgRecent.toStringAsFixed(metric == 'Blood Pressure' || metric == 'Heart Rate' ? 0 : 1)} $unit'
            '${target != null ? ' · Target: ${metric == 'Blood Pressure' || metric == 'Heart Rate' ? target.toInt() : target.toStringAsFixed(1)} $unit' : ''}',
            style: TextStyle(fontSize: 12, color: cardColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(specificMsg,
              style: TextStyle(fontSize: 12, color: _text2, height: 1.4)),
        ],
      ),
    );
  }

  Widget _chartEmpty(String msg) => Container(
    height: 150,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.show_chart_rounded, color: _blue.withValues(alpha: 0.3), size: 36),
        const SizedBox(height: 8),
        Text(msg, style: const TextStyle(color: _text2, fontSize: 13)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DAILY CHECK-IN TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ChronicVitalsRec extends StatelessWidget {
  const _ChronicVitalsRec();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Keep tracking your vitals daily — consistent monitoring helps your care team adjust your treatment plan and catch changes early.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1E3A5F), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessVitalsRec extends StatelessWidget {
  const _WellnessVitalsRec();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Wellness tip: BP under 120/80 mmHg and fasting glucose under 5.6 mmol/L are healthy targets. A 30-min daily walk improves both cardiovascular and metabolic health.',
              style: TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCheckInTab extends StatelessWidget {
  final VitalsState state;

  static const _bg     = Color(0xFFF2F4F8);
  static const _text1  = Color(0xFF0D1117);
  static const _text2  = Color(0xFF6B7280);
  static const _blue   = Color(0xFF007AFF);
  static const _green  = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red    = Color(0xFFFF3B30);

  const _DailyCheckInTab({required this.state});

  Color _painColor(int p) {
    if (p <= 3) return _green;
    if (p <= 6) return _orange;
    return _red;
  }

  String _painLabel(int p) {
    if (p == 0) return 'No Pain';
    if (p <= 2) return 'Mild';
    if (p <= 4) return 'Moderate';
    if (p <= 6) return 'Considerable';
    if (p <= 8) return 'Severe';
    return 'Worst Pain';
  }

  Color _moodColor(String m) {
    switch (m.toLowerCase()) {
      case 'great':    return _green;
      case 'good':     return const Color(0xFF32ADE6);
      case 'okay':     return _orange;
      case 'bad':      return const Color(0xFFFF6B35);
      case 'terrible': return _red;
      default:         return _text2;
    }
  }

  String _moodEmoji(String m) {
    switch (m.toLowerCase()) {
      case 'great':    return '😄';
      case 'good':     return '🙂';
      case 'okay':     return '😐';
      case 'bad':      return '😕';
      case 'terrible': return '😞';
      default:         return '😐';
    }
  }

  String _moodDesc(String m) {
    switch (m.toLowerCase()) {
      case 'great':    return 'Feeling fantastic today!';
      case 'good':     return 'Having a good day.';
      case 'okay':     return 'Getting through the day.';
      case 'bad':      return 'Not feeling great today.';
      case 'terrible': return 'Having a really tough day.';
      default:         return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest == null || (latest.painLevel == null && latest.mood == null))
            _noCheckIn(context)
          else ...[
            if (latest.painLevel != null) _painCard(latest.painLevel!),
            if (latest.painLevel != null) const SizedBox(height: 16),
            if (latest.mood != null) _moodCard(latest.mood!),
            const SizedBox(height: 20),
          ],
          _logButton(context),
        ],
      ),
    );
  }

  Widget _painCard(int pain) {
    final col = _painColor(pain);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: 0.12)),
                child: Icon(Icons.whatshot_rounded, color: col, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pain Level', style: TextStyle(fontSize: 13, color: _text2)),
                  Text('How you feel today', style: TextStyle(fontSize: 11, color: _text2)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$pain / 10',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Pain dot scale
          Row(
            children: List.generate(10, (i) {
              final active = i < pain;
              final dotCol = active
                ? (i < 3 ? _green : i < 6 ? _orange : _red)
                : const Color(0xFFE5E7EB);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: active ? 10 : 8,
                    decoration: BoxDecoration(
                      color: dotCol,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('None', style: TextStyle(fontSize: 10, color: _text2)),
              Text(_painLabel(pain),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col)),
              const Text('Severe', style: TextStyle(fontSize: 10, color: _text2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodCard(String mood) {
    final col  = _moodColor(mood);
    final emoji = _moodEmoji(mood);
    final desc  = _moodDesc(mood);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: 0.1)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mood Check-in', style: TextStyle(fontSize: 12, color: _text2)),
                const SizedBox(height: 3),
                Text(mood.toUpperCase(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: _text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noCheckIn(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
    ),
    child: Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withValues(alpha: 0.08)),
          child: const Icon(Icons.check_circle_rounded, color: _blue, size: 36),
        ),
        const SizedBox(height: 16),
        const Text("No check-in today",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text1)),
        const SizedBox(height: 6),
        const Text("Log your vitals to include today's pain and mood check-in.",
          style: TextStyle(fontSize: 13, color: _text2), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _logButton(BuildContext context) => SizedBox(
    height: 50,
    child: ElevatedButton.icon(
      onPressed: () => context.push(routeLogVitals),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
      icon: const Icon(Icons.edit_note_rounded),
      label: const Text("Log Today's Check-in",
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOOD HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _MoodHistoryTab extends StatelessWidget {
  final VitalsState state;

  static const _bg    = Color(0xFFF2F4F8);
  static const _text1 = Color(0xFF0D1117);
  static const _text2 = Color(0xFF6B7280);
  static const _blue  = Color(0xFF007AFF);

  static const Map<String, Color> _moodColors = {
    'great':    Color(0xFF34C759),
    'good':     Color(0xFF32ADE6),
    'okay':     Color(0xFFFF9500),
    'bad':      Color(0xFFFF6B35),
    'terrible': Color(0xFFFF3B30),
  };

  static const Map<String, String> _moodEmoji = {
    'great':    '😄',
    'good':     '🙂',
    'okay':     '😐',
    'bad':      '😕',
    'terrible': '😞',
  };

  const _MoodHistoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final moodLogs = state.vitals.where((v) => v.mood != null).toList();

    if (moodLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withValues(alpha: 0.08)),
              child: const Icon(Icons.mood_rounded, color: _blue, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('No mood history yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text1)),
            const SizedBox(height: 6),
            const Text('Log vitals with mood check-ins to see history here.',
              style: TextStyle(fontSize: 13, color: _text2), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: moodLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final v   = moodLogs[i];
        final key = v.mood!.toLowerCase();
        final col = _moodColors[key] ?? _text2;
        final em  = _moodEmoji[key] ?? '😐';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: col, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: 0.1)),
                  child: Center(child: Text(em, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.mood!.toUpperCase(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(DateFormat('EEE, d MMM y · HH:mm').format(v.loggedAt),
                        style: const TextStyle(fontSize: 12, color: _text2)),
                    ],
                  ),
                ),
                if (v.painLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Pain ${v.painLevel}/10',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CycleTrackerEntryCard extends ConsumerWidget {
  const _CycleTrackerEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cycleTrackerProvider);
    if (!state.visible) return const SizedBox.shrink();
    final stats = state.stats;

    String headline;
    String sub;
    if (stats.lastPeriodStart == null) {
      headline = 'Cycle Tracker';
      sub = 'Tap to log your first period';
    } else if (stats.isInPeriod) {
      headline = 'Period • Day ${stats.currentCycleDay}';
      sub = 'Tap to view your cycle calendar';
    } else {
      final days = stats.daysUntilNextPeriod ?? 0;
      headline = days <= 0
          ? 'Period overdue'
          : (days == 1 ? 'Period in 1 day' : 'Period in $days days');
      sub = 'Avg cycle ${stats.avgCycleLength}d • period ${stats.avgPeriodLength}d';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(routeCycleTracker),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFFF06292)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
