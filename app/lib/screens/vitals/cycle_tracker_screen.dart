import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/cycle.dart';
import '../../providers/cycle_tracker_provider.dart';

class CycleTrackerScreen extends ConsumerWidget {
  const CycleTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cycleTrackerProvider);
    final stats = state.stats;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Cycle Tracker',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => _showSettings(context, ref),
          ),
        ],
      ),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _StatusBanner(stats: stats),
                  const SizedBox(height: 16),
                  _StatsRow(stats: stats),
                  const SizedBox(height: 20),
                  _CalendarSection(state: state),
                  const SizedBox(height: 20),
                  _HistorySection(entries: state.entries.reversed.toList()),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        onPressed: () => _openLogSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log Period'),
      ),
    );
  }

  void _openLogSheet(BuildContext context, WidgetRef ref,
      {CycleEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogPeriodSheet(existing: existing),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    final state = ref.read(cycleTrackerProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final s = ref.watch(cycleTrackerProvider);
          return AlertDialog(
            title: const Text('Cycle Tracker Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reminders'),
                  subtitle: const Text(
                      'Notify me before my period and on ovulation day.'),
                  value: s.remindersEnabled,
                  onChanged: (v) => ref
                      .read(cycleTrackerProvider.notifier)
                      .setRemindersEnabled(v),
                ),
                const Divider(),
                Text(
                  'Average cycle: ${state.stats.avgCycleLength} days',
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  'Average period: ${state.stats.avgPeriodLength} days',
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  '${state.entries.length} period(s) logged',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Status banner ───────────────────────────────────────────────────────────

class _StatusBanner extends ConsumerWidget {
  final CycleStats stats;
  const _StatusBanner({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String subtitle;
    Color color;
    IconData icon;

    if (stats.lastPeriodStart == null) {
      title = 'Get started';
      subtitle = 'Tap "Log Period" to start tracking your cycle.';
      color = const Color(0xFFE91E63);
      icon = Icons.favorite_rounded;
    } else if (stats.isInPeriod) {
      title = 'Period — Day ${stats.currentCycleDay}';
      subtitle = 'You are currently on your period.';
      color = const Color(0xFFE53935);
      icon = Icons.water_drop_rounded;
    } else if (stats.predictedOvulation != null &&
        DateTime.now().isAfter(stats.fertileWindowStart!.subtract(const Duration(days: 1))) &&
        DateTime.now().isBefore(stats.fertileWindowEnd!.add(const Duration(days: 1)))) {
      title = 'Fertile window';
      final ovDate = DateFormat('EEE, d MMM').format(stats.predictedOvulation!);
      subtitle = 'Predicted ovulation: $ovDate';
      color = const Color(0xFF26A69A);
      icon = Icons.eco_rounded;
    } else {
      final days = stats.daysUntilNextPeriod ?? 0;
      title = days <= 0
          ? 'Period overdue'
          : (days == 1 ? 'Period in 1 day' : 'Period in $days days');
      final nextDate = stats.predictedNextStart != null
          ? DateFormat('EEE, d MMM').format(stats.predictedNextStart!)
          : '—';
      subtitle = 'Predicted start: $nextDate';
      color = days <= 3 ? const Color(0xFFEF6C00) : const Color(0xFFE91E63);
      icon = Icons.calendar_month_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final CycleStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _statTile('Avg Cycle', '${stats.avgCycleLength}', 'days', kPrimary),
        const SizedBox(width: 10),
        _statTile('Avg Period', '${stats.avgPeriodLength}', 'days',
            const Color(0xFFE53935)),
        const SizedBox(width: 10),
        _statTile(
            'Cycle Day',
            stats.currentCycleDay?.toString() ?? '—',
            'today',
            const Color(0xFF26A69A)),
      ],
    );
  }

  Widget _statTile(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 22,
                        color: color,
                        fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Calendar (next ~6 weeks) ────────────────────────────────────────────────

class _CalendarSection extends StatelessWidget {
  final CycleTrackerState state;
  const _CalendarSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 7));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle Calendar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Past week + next 5 weeks',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: days.map((d) => _dayCell(d, today, stats)).toList(),
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime d, DateTime today, CycleStats stats) {
    final isToday = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;

    final isLoggedPeriod = state.entries.any((e) {
      final start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = e.endDate != null
          ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
          : start.add(Duration(days: stats.avgPeriodLength - 1));
      return !d.isBefore(start) && !d.isAfter(end);
    });
    final isPredictedPeriod = !isLoggedPeriod && stats.isPredictedPeriod(d);
    final isOvulation = stats.isOvulation(d);
    final isFertile = !isOvulation && stats.isFertile(d);

    Color bg = Colors.transparent;
    Color fg = Colors.black87;
    if (isLoggedPeriod) {
      bg = const Color(0xFFE53935);
      fg = Colors.white;
    } else if (isPredictedPeriod) {
      bg = const Color(0xFFFCE4EC);
      fg = const Color(0xFFC2185B);
    } else if (isOvulation) {
      bg = const Color(0xFF26A69A);
      fg = Colors.white;
    } else if (isFertile) {
      bg = const Color(0xFFE0F2F1);
      fg = const Color(0xFF00796B);
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: kPrimary, width: 2)
            : (bg == Colors.transparent
                ? Border.all(color: const Color(0xFFEEEEEE))
                : null),
      ),
      child: Center(
        child: Text(
          '${d.day}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget chip(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        chip(const Color(0xFFE53935), 'Period'),
        chip(const Color(0xFFFCE4EC), 'Predicted period'),
        chip(const Color(0xFF26A69A), 'Ovulation'),
        chip(const Color(0xFFE0F2F1), 'Fertile'),
      ],
    );
  }
}

// ─── History list ────────────────────────────────────────────────────────────

class _HistorySection extends ConsumerWidget {
  final List<CycleEntry> entries;
  const _HistorySection({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        ...entries.map((e) => _entryTile(context, ref, e)),
      ],
    );
  }

  Widget _entryTile(BuildContext context, WidgetRef ref, CycleEntry e) {
    final df = DateFormat('d MMM yyyy');
    final endStr =
        e.endDate != null ? df.format(e.endDate!) : 'Ongoing';
    final lenStr = e.periodLengthDays != null
        ? '${e.periodLengthDays} days'
        : '—';
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFE53935),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete period entry?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) =>
          ref.read(cycleTrackerProvider.notifier).deleteEntry(e.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.water_drop_rounded,
                  color: Color(0xFFE91E63), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${df.format(e.startDate)} → $endStr',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.flow.label} flow • $lenStr'
                    '${e.symptoms.isNotEmpty ? ' • ${e.symptoms.length} symptom(s)' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (e.notes != null && e.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e.notes!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            if (e.endDate == null)
              TextButton(
                onPressed: () => ref
                    .read(cycleTrackerProvider.notifier)
                    .endCurrentPeriod(),
                child: const Text('End'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Log / edit period bottom sheet ──────────────────────────────────────────

class _LogPeriodSheet extends ConsumerStatefulWidget {
  final CycleEntry? existing;
  const _LogPeriodSheet({this.existing});

  @override
  ConsumerState<_LogPeriodSheet> createState() => _LogPeriodSheetState();
}

class _LogPeriodSheetState extends ConsumerState<_LogPeriodSheet> {
  late DateTime _startDate;
  DateTime? _endDate;
  late FlowLevel _flow;
  late Set<String> _symptoms;
  String? _mood;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
    _flow = e?.flow ?? FlowLevel.medium;
    _symptoms = {...?e?.symptoms};
    _mood = e?.mood;
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(cycleTrackerProvider.notifier);
    final e = widget.existing;
    if (e == null) {
      await notifier.addEntry(CycleEntry(
        id: 'cyc_${DateTime.now().microsecondsSinceEpoch}',
        startDate: _startDate,
        endDate: _endDate,
        flow: _flow,
        symptoms: _symptoms.toList(),
        mood: _mood,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
    } else {
      await notifier.updateEntry(e.copyWith(
        startDate: _startDate,
        endDate: _endDate,
        clearEndDate: _endDate == null,
        flow: _flow,
        symptoms: _symptoms.toList(),
        mood: _mood,
        clearMood: _mood == null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        clearNotes: _notesCtrl.text.trim().isEmpty,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, d MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Log Period' : 'Edit Period',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Start date'),
            _dateField(df.format(_startDate), () => _pickDate(isStart: true)),
            const SizedBox(height: 12),
            _label('End date (optional)'),
            _dateField(
              _endDate == null ? 'Still ongoing' : df.format(_endDate!),
              () => _pickDate(isStart: false),
              trailing: _endDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _endDate = null),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _label('Flow'),
            Wrap(
              spacing: 8,
              children: FlowLevel.values
                  .map((f) => ChoiceChip(
                        label: Text(
                          f.label,
                          style: TextStyle(
                            color: _flow == f
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: _flow == f,
                        backgroundColor: const Color(0xFFF1F1F4),
                        selectedColor: const Color(0xFFE91E63),
                        onSelected: (_) => setState(() => _flow = f),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('Symptoms'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kCycleSymptomSuggestions
                  .map((s) => FilterChip(
                        label: Text(
                          s,
                          style: TextStyle(
                            color: _symptoms.contains(s)
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        selected: _symptoms.contains(s),
                        backgroundColor: const Color(0xFFF1F1F4),
                        selectedColor: const Color(0xFFE91E63),
                        checkmarkColor: Colors.white,
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _symptoms.add(s);
                          } else {
                            _symptoms.remove(s);
                          }
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('Mood'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kCycleMoodOptions
                  .map((m) => ChoiceChip(
                        label: Text(
                          m,
                          style: TextStyle(
                            color: _mood == m
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        selected: _mood == m,
                        backgroundColor: const Color(0xFFF1F1F4),
                        selectedColor: const Color(0xFFE91E63),
                        onSelected: (_) =>
                            setState(() => _mood = _mood == m ? null : m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('Notes'),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Anything else worth remembering…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _save,
                child:
                    Text(widget.existing == null ? 'Save Period' : 'Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black87)),
      );

  Widget _dateField(String value, VoidCallback onTap, {Widget? trailing}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
