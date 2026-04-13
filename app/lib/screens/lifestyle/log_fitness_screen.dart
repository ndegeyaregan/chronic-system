import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/lifestyle_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class LogFitnessScreen extends ConsumerStatefulWidget {
  const LogFitnessScreen({super.key});

  @override
  ConsumerState<LogFitnessScreen> createState() => _LogFitnessScreenState();
}

class _LogFitnessScreenState extends ConsumerState<LogFitnessScreen> {
  String _activityType = 'walking';
  final _stepsCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Timer state
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _timerRunning = false;

  final _activities = [
    {'key': 'walking', 'label': 'Walking', 'emoji': '🚶'},
    {'key': 'running', 'label': 'Running', 'emoji': '🏃'},
    {'key': 'cycling', 'label': 'Cycling', 'emoji': '🚴'},
    {'key': 'rope_skipping', 'label': 'Rope Skipping', 'emoji': '🪢'},
    {'key': 'gym', 'label': 'Gym', 'emoji': '🏋️'},
    {'key': 'swimming', 'label': 'Swimming', 'emoji': '🏊'},
    {'key': 'other', 'label': 'Other', 'emoji': '⚡'},
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _stepsCtrl.dispose();
    _durationCtrl.dispose();
    _caloriesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timerRunning = true;
      _elapsedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    final minutes = (_elapsedSeconds / 60).ceil();
    setState(() {
      _timerRunning = false;
      _durationCtrl.text = minutes.toString();
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _elapsedSeconds = 0;
      _durationCtrl.clear();
    });
  }

  String get _timerDisplay {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _estimatedCalories {
    final steps = int.tryParse(_stepsCtrl.text);
    final duration = int.tryParse(_durationCtrl.text);
    if (steps != null && steps > 0) return (steps * 0.04).round();
    if (duration != null && duration > 0) return duration * 5;
    return 0;
  }

  Future<void> _submit() async {
    if (_durationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or record the duration of your activity.'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }

    final success = await ref.read(lifestyleProvider.notifier).logFitness({
      'activity_type': _activityType,
      if (_stepsCtrl.text.isNotEmpty)
        'steps': int.tryParse(_stepsCtrl.text),
      'duration_minutes': int.tryParse(_durationCtrl.text) ?? 0,
      if (_caloriesCtrl.text.isNotEmpty)
        'calories_burned': int.tryParse(_caloriesCtrl.text),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity logged successfully!'),
          backgroundColor: kSuccess,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);
    final todaySteps = state.todaySteps;
    final todayActiveMinutes = state.todayActiveMinutes;
    const stepsGoal = 10000;
    const minutesGoal = 30;
    final stepsProgress = (todaySteps / stepsGoal).clamp(0.0, 1.0);
    final minutesProgress = (todayActiveMinutes / minutesGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Log Activity'),
        backgroundColor: const Color(0xFF003DA5),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily targets
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.08), kAccent.withValues(alpha: 0.06)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📊 Today's Progress",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText),
                  ),
                  const SizedBox(height: 12),
                  _buildProgressRow(
                    '👣 Steps',
                    '$todaySteps / $stepsGoal',
                    stepsProgress,
                    kPrimary,
                  ),
                  const SizedBox(height: 10),
                  _buildProgressRow(
                    '⏱️ Active Minutes',
                    '$todayActiveMinutes / $minutesGoal min',
                    minutesProgress,
                    kAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Activity type selector
            const Text(
              'Activity Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: _activities
                  .map(
                    (a) => GestureDetector(
                      onTap: () => setState(() => _activityType = a['key']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: _activityType == a['key'] ? kPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _activityType == a['key'] ? kPrimary : kBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a['emoji']!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              a['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _activityType == a['key'] ? Colors.white : kText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Auto-timer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '⏱️ Activity Timer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _timerRunning
                          ? kPrimary.withValues(alpha: 0.08)
                          : kBg,
                      border: Border.all(
                        color: _timerRunning ? kPrimary : kBorder,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _timerDisplay,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _timerRunning ? kPrimary : kSubtext,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_timerRunning) ...[
                        ElevatedButton.icon(
                          onPressed: _startTimer,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSuccess,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                        if (_elapsedSeconds > 0) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _resetTimer,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ],
                      ] else
                        ElevatedButton.icon(
                          onPressed: _stopTimer,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop & Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kError,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                    ],
                  ),
                  if (_elapsedSeconds > 0 && !_timerRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Duration auto-filled: ${_durationCtrl.text} min',
                        style: const TextStyle(fontSize: 12, color: kSuccess),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Manual fields
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: 'Duration (minutes)',
                    hint: 'e.g. 30',
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput(
                    label: 'Steps (optional)',
                    hint: 'e.g. 5000',
                    controller: _stepsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Calories Burned (optional)',
              hint: 'e.g. 250',
              controller: _caloriesCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Notes (optional)',
              hint: 'e.g. Morning run in the park',
              controller: _notesCtrl,
              maxLines: 2,
            ),

            // Summary card
            if (_activityType.isNotEmpty && _durationCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Activity Summary',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText),
                    ),
                    const SizedBox(height: 10),
                    _summaryRow('Activity',
                        _activities.firstWhere((a) => a['key'] == _activityType,
                            orElse: () => {'label': _activityType})['label']!),
                    _summaryRow('Duration', '${_durationCtrl.text} minutes'),
                    if (_stepsCtrl.text.isNotEmpty)
                      _summaryRow('Steps', _stepsCtrl.text),
                    _summaryRow(
                      'Est. Calories',
                      _caloriesCtrl.text.isNotEmpty
                          ? '${_caloriesCtrl.text} kcal'
                          : '~$_estimatedCalories kcal (estimated)',
                    ),
                  ],
                ),
              ),
            ],

            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: kError, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            AppButton(
              label: 'Log Activity',
              onPressed: _submit,
              isLoading: state.isLoading,
              leadingIcon: Icons.fitness_center_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: kText)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: kSubtext)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText)),
          ),
        ],
      ),
    );
  }
}
