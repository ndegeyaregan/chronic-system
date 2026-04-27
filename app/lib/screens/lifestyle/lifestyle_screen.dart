import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/lifestyle_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/step_tracking_provider.dart';
import '../../services/notification_service.dart';
import 'fitness_tracker_screen.dart';

class LifestyleScreen extends ConsumerStatefulWidget {
  const LifestyleScreen({super.key});

  @override
  ConsumerState<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends ConsumerState<LifestyleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

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

  Widget _tab(IconData icon, String label, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Lifestyle & Wellness',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            _tab(Icons.psychology_rounded,    'Psychosocial', const Color(0xFF32ADE6)),
            _tab(Icons.restaurant_rounded,    'Nutrition',    const Color(0xFF34C759)),
            _tab(Icons.fitness_center_rounded,'Fitness',      const Color(0xFFFF9500)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PsychosocialTab(),
          _NutritionTab(),
          _FitnessTab(),
        ],
      ),
    );
  }
}

class _PsychosocialTab extends ConsumerStatefulWidget {
  const _PsychosocialTab();

  @override
  ConsumerState<_PsychosocialTab> createState() => _PsychosocialTabState();
}

class _PsychosocialTabState extends ConsumerState<_PsychosocialTab> {
  bool _breathingActive = false;
  bool _expanding = true;
  bool _showStressAlert = false;
  String _breathPhase = 'inhale'; // 'inhale' | 'hold' | 'exhale' | 'rest'
  int _currentRound = 0;
  final int _totalRounds = 5;
  int _countdown = 4;
  Timer? _breathingTimer;
  DateTime? _breathingStartTime;

  void _toggleBreathing() {
    if (_breathingActive) {
      _breathingTimer?.cancel();
      setState(() {
        _breathingActive = false;
        _breathPhase = 'inhale';
        _expanding = true;
        _currentRound = 0;
        _countdown = 4;
      });
    } else {
      setState(() {
        _breathingActive = true;
        _breathPhase = 'inhale';
        _expanding = true;
        _currentRound = 1;
        _countdown = 4;
        _breathingStartTime = DateTime.now();
      });
      _runBreathingCycle();
    }
  }

  void _runBreathingCycle() {
    _breathingTimer?.cancel();
    // Each tick = 1 second
    // Sequence per round: inhale(4s), hold(4s), exhale(4s), rest(2s)
    final sequence = [
      ('inhale', 4, true),
      ('hold', 4, true),
      ('exhale', 4, false),
      ('rest', 2, false),
    ];
    int seqIdx = 0;
    int elapsed = 0;
    int phaseDuration = sequence[seqIdx].$2;

    void onTick(Timer t) {
      if (!mounted || !_breathingActive) {
        t.cancel();
        return;
      }
      elapsed++;
      if (mounted) {
        setState(() => _countdown = phaseDuration - elapsed);
      }
      if (elapsed >= phaseDuration) {
        elapsed = 0;
        seqIdx++;
        if (seqIdx >= sequence.length) {
          // Round complete
          final nextRound = _currentRound + 1;
          if (nextRound > _totalRounds) {
            t.cancel();
            // Log breathing exercise completion
            final durationSecs = _breathingStartTime != null
                ? DateTime.now().difference(_breathingStartTime!).inSeconds
                : (_totalRounds * 14); // 14s per round (4+4+4+2)
            ref.read(lifestyleProvider.notifier)
                .logBreathingCompletion(_totalRounds, durationSecs);
            if (mounted) {
              setState(() {
                _breathingActive = false;
                _breathPhase = 'inhale';
                _expanding = true;
                _currentRound = 0;
                _countdown = 4;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🌬️ Breathing exercise completed! Great job.'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            }
            return;
          }
          seqIdx = 0;
          if (mounted) setState(() => _currentRound = nextRound);
        }
        final (phase, dur, exp) = sequence[seqIdx];
        phaseDuration = dur;
        if (mounted) {
          setState(() {
            _breathPhase = phase;
            _expanding = exp;
            _countdown = dur;
          });
        }
      }
    }

    _breathingTimer = Timer.periodic(const Duration(seconds: 1), onTick);
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    super.dispose();
  }

  Future<void> _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _onSliderChanged() {
    final state = ref.read(lifestyleProvider);
    if (state.stressLevel > 6 || state.anxietyLevel > 6) {
      if (!_showStressAlert) {
        setState(() => _showStressAlert = true);
      }
      NotificationService.show(
        id: 200,
        title: '🧠 High Stress Detected',
        body: 'Your stress level is elevated. Try the breathing exercise now.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);
    final conditions = ref.watch(memberProvider).member?.conditions ?? [];
    final stressRecs = _psychosocialRecs(conditions, state.stressLevel);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Support Resources — ALWAYS VISIBLE AT TOP ─────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(kRadiusLg),
              border:
                  Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: Color(0xFF16A34A), size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Need to talk to someone?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _supportButton(
                  icon: Icons.phone_rounded,
                  label: 'SanCare Health Helpline',
                  subtitle: '+256 753 115723 · Available 24/7',
                  color: const Color(0xFF16A34A),
                  onTap: () => _callHelpline('+256753115723'),
                ),
                const SizedBox(height: 8),
                _supportButton(
                  icon: Icons.headset_mic_rounded,
                  label: 'SanCare Support Line',
                  subtitle: '+256 783 970079 · Member Assistance',
                  color: kPrimary,
                  onTap: () => _callHelpline('+256783970079'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── How are you feeling today? ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How are you feeling today?',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: kText),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    {'emoji': '😄', 'label': 'Great', 'key': 'great'},
                    {'emoji': '🙂', 'label': 'Good', 'key': 'good'},
                    {'emoji': '😐', 'label': 'Okay', 'key': 'okay'},
                    {'emoji': '😔', 'label': 'Bad', 'key': 'bad'},
                    {'emoji': '😢', 'label': 'Low', 'key': 'terrible'},
                  ].map((m) {
                    final key = m['key']!;
                    final selected = state.moodCheckIn == key;
                    return GestureDetector(
                      onTap: () => ref
                          .read(lifestyleProvider.notifier)
                          .updatePsychosocial(mood: key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? kPrimary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(kRadiusMd),
                          border: Border.all(
                            color:
                                selected ? kPrimary : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(m['emoji']!,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              m['label']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: selected ? kPrimary : kSubtext,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (state.moodCheckIn == 'bad' ||
                    state.moodCheckIn == 'terrible') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius:
                          BorderRadius.circular(kRadiusMd),
                      border: Border.all(
                          color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volunteer_activism_rounded,
                            color: Color(0xFFEA580C), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'It\'s okay to ask for help. Reach out using the support line above.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEA580C),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Stress & Anxiety sliders ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check-in',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: kText),
                ),
                const SizedBox(height: 16),
                _levelSlider(
                  label: 'Stress Level',
                  value: state.stressLevel,
                  icon: Icons.bolt_rounded,
                  onChanged: (v) {
                    ref
                        .read(lifestyleProvider.notifier)
                        .updatePsychosocial(stress: v);
                    _onSliderChanged();
                  },
                ),
                const SizedBox(height: 14),
                _levelSlider(
                  label: 'Anxiety Level',
                  value: state.anxietyLevel,
                  icon: Icons.waves_rounded,
                  onChanged: (v) {
                    ref
                        .read(lifestyleProvider.notifier)
                        .updatePsychosocial(anxiety: v);
                    _onSliderChanged();
                  },
                ),
              ],
            ),
          ),
          // ── High stress alert ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showStressAlert ? null : 0,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: _showStressAlert
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.circular(kRadiusMd),
                        border: Border.all(
                            color: kWarning.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.self_improvement_rounded,
                                  color: kWarning, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'High Stress Detected',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kText),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _showStressAlert = false),
                                child: const Icon(Icons.close,
                                    size: 16, color: kSubtext),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...stressRecs.map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🌿', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rec,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: kSubtext,
                                        height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          // ── Breathing exercise ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1628), Color(0xFF0E2E6B)],
              ),
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.air_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🌬️ Breathing Exercise',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                          Text('Box Breathing · Proven to reduce stress & BP',
                              style: TextStyle(fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Phase label (large)
                Text(
                  _breathingActive
                      ? _breathPhase.toUpperCase()
                      : 'TAP TO BEGIN',
                  style: TextStyle(
                    color: _breathingActive
                        ? const Color(0xFF60B8FF)
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                // Countdown
                if (_breathingActive)
                  Text(
                    '$_countdown s',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 20),
                // Animated circle
                SizedBox(
                  width: 160, height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeInOut,
                        width: _breathingActive && _expanding ? 160 : 100,
                        height: _breathingActive && _expanding ? 160 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeInOut,
                        width: _breathingActive && _expanding ? 120 : 78,
                        height: _breathingActive && _expanding ? 120 : 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeInOut,
                        width: _breathingActive && _expanding ? 90 : 60,
                        height: _breathingActive && _expanding ? 90 : 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF60B8FF).withValues(alpha: 0.85),
                              const Color(0xFF1A56C4).withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: _breathingActive
                              ? [BoxShadow(color: const Color(0xFF60B8FF).withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4)]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            _breathingActive
                                ? (_breathPhase == 'inhale' ? 'Inhale'
                                    : _breathPhase == 'hold' ? 'Hold'
                                    : _breathPhase == 'exhale' ? 'Exhale'
                                    : 'Rest')
                                : 'Start',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Round indicator
                if (_breathingActive) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Round $_currentRound of $_totalRounds   ',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      ...List.generate(_totalRounds, (i) => Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _currentRound
                              ? const Color(0xFF60B8FF)
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Start / Stop button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleBreathing,
                    icon: Icon(_breathingActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_breathingActive ? 'Stop Exercise' : 'Start Exercise'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _breathingActive
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFF60B8FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Breathing stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: Color(0xFF60B8FF), size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '${state.breathingCompletionsThisWeek} this week · ${state.breathingCompletionCount} total',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lowers HR · Reduces BP · Calms anxiety',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Mood & Stress History ──────────────────────────────────
          if (state.psychosocialHistory.isNotEmpty)
            _buildMoodStressHistory(state.psychosocialHistory),
          const SizedBox(height: 18),
          // ── Find Counselor button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('$routePartners?type=counsellor'),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Find Counselor'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelSlider({
    required String label,
    required int value,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    final color = _stressColor(value);
    final labels = ['', 'Very Low', '', 'Low', '', 'Moderate', '', 'High', '', 'Very High', 'Extreme'];
    final levelLabel = value <= labels.length - 1 ? labels[value] : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSubtext),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(kRadiusFull),
              ),
              child: Text(
                '$value · $levelLabel',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _supportButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: kSubtext),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Color _stressColor(int level) {
    if (level <= 3) return kSuccess;
    if (level <= 6) return kWarning;
    return kError;
  }

  Widget _buildMoodStressHistory(List<PsychosocialCheckin> history) {
    // Sort chronologically (oldest first) for chart
    final sorted = [...history]
      ..sort((a, b) => a.checkinDate.compareTo(b.checkinDate));

    // Group by date — take the latest entry per day
    final Map<String, PsychosocialCheckin> byDate = {};
    for (final c in sorted) {
      final key = '${c.checkinDate.year}-${c.checkinDate.month}-${c.checkinDate.day}';
      byDate[key] = c;
    }
    final entries = byDate.values.toList()
      ..sort((a, b) => a.checkinDate.compareTo(b.checkinDate));

    // Limit to last 14 data points for readability
    final limited = entries.length > 14
        ? entries.sublist(entries.length - 14)
        : entries;

    // Build chart spots
    final moodSpots = <FlSpot>[];
    final stressSpots = <FlSpot>[];
    final anxietySpots = <FlSpot>[];
    for (var i = 0; i < limited.length; i++) {
      final c = limited[i];
      if (c.moodNumeric > 0) {
        moodSpots.add(FlSpot(i.toDouble(), c.moodNumeric.toDouble()));
      }
      if (c.stressLevel != null) {
        stressSpots.add(FlSpot(i.toDouble(), c.stressLevel!.toDouble()));
      }
      if (c.anxietyLevel != null) {
        anxietySpots.add(FlSpot(i.toDouble(), c.anxietyLevel!.toDouble()));
      }
    }

    if (moodSpots.isEmpty && stressSpots.isEmpty && anxietySpots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded,
                    color: kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mood & Stress History',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: kText)),
                    Text('Your check-in trends over time',
                        style: TextStyle(fontSize: 11, color: kSubtext)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Legend
          Wrap(
            spacing: 14,
            children: [
              if (moodSpots.isNotEmpty)
                _chartLegend('Mood', const Color(0xFF10B981)),
              if (stressSpots.isNotEmpty)
                _chartLegend('Stress', const Color(0xFFEF4444)),
              if (anxietySpots.isNotEmpty)
                _chartLegend('Anxiety', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: kBorder.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 2,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            fontSize: 10, color: kSubtext),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (limited.length / 5).ceilToDouble().clamp(1, 10),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= limited.length) {
                          return const SizedBox();
                        }
                        final d = limited[idx].checkinDate;
                        return Text(
                          '${d.day}/${d.month}',
                          style: const TextStyle(
                              fontSize: 9, color: kSubtext),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  if (moodSpots.length >= 2)
                    _chartLine(moodSpots, const Color(0xFF10B981)),
                  if (stressSpots.length >= 2)
                    _chartLine(stressSpots, const Color(0xFFEF4444)),
                  if (anxietySpots.length >= 2)
                    _chartLine(anxietySpots, const Color(0xFFF59E0B)),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      String label;
                      if (s.barIndex == 0 && moodSpots.length >= 2) {
                        label = 'Mood';
                      } else if (s.barIndex == 1 && stressSpots.length >= 2) {
                        label = 'Stress';
                      } else {
                        label = 'Anxiety';
                      }
                      return LineTooltipItem(
                        '$label: ${s.y.toInt()}',
                        TextStyle(
                          color: s.bar.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          // Mood emoji scale reference
          if (moodSpots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('😢 1', style: TextStyle(fontSize: 10, color: kSubtext)),
                const Text('😔 2', style: TextStyle(fontSize: 10, color: kSubtext)),
                const Text('😐 3', style: TextStyle(fontSize: 10, color: kSubtext)),
                const Text('🙂 4', style: TextStyle(fontSize: 10, color: kSubtext)),
                const Text('😄 5', style: TextStyle(fontSize: 10, color: kSubtext)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  LineChartBarData _chartLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3,
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
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _NutritionTab extends ConsumerWidget {
  const _NutritionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifestyleProvider);
    const calorieGoal = 2000;
    final consumed = state.todayCalories;
    final remaining = (calorieGoal - consumed).clamp(0, calorieGoal);
    final progress = (consumed / calorieGoal).clamp(0.0, 1.0);
    final overGoal = consumed > calorieGoal;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── MFP-style calorie ring card ────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: [
                // Calorie ring
                SizedBox(
                  width: 108,
                  height: 108,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: kBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            overGoal ? kError : kAccent,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            overGoal
                                ? '+${consumed - calorieGoal}'
                                : '$remaining',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: overGoal ? kError : kText,
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            overGoal ? 'over' : 'remaining',
                            style: const TextStyle(
                                fontSize: 9, color: kSubtext),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Stats column
                Expanded(
                  child: Column(
                    children: [
                      _calRow('Goal', '$calorieGoal', 'kcal',
                          const Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      _calRow('Consumed', '$consumed', 'kcal', kAccent),
                      const SizedBox(height: 12),
                      _calRow(
                        overGoal ? 'Over' : 'Remaining',
                        overGoal
                            ? '${consumed - calorieGoal}'
                            : '$remaining',
                        'kcal',
                        overGoal ? kError : kPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Water intake ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        color: Color(0xFF3B82F6), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Water Intake',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kText),
                    ),
                    const Spacer(),
                    Text(
                      '${state.waterCups} / 8 cups',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(8, (i) {
                    final filled = i < state.waterCups;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!filled) {
                            ref
                                .read(lifestyleProvider.notifier)
                                .addWaterCup();
                          } else if (i == state.waterCups - 1) {
                            ref
                                .read(lifestyleProvider.notifier)
                                .removeWaterCup();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 36,
                          decoration: BoxDecoration(
                            color: filled
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            Icons.water_drop,
                            size: 15,
                            color: filled
                                ? Colors.white
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.waterCups / 8,
                    backgroundColor: kBorder,
                    valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF3B82F6)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Log Meal button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push(routeLogMeal),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log Meal'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Find Nutritionist button ───────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('$routePartners?type=nutritionist'),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Find Nutritionist'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Diet Tips for Your Conditions ─────────────────────────
          Builder(builder: (_) {
            final conds = ref.watch(memberProvider).member?.conditions ?? [];
            final allTips = <String>[];
            final matchedConds = <String>[];
            for (final c in conds) {
              final cl = c.toLowerCase();
              for (final entry in _conditionDietTips.entries) {
                if (cl.contains(entry.key) && !matchedConds.contains(c)) {
                  matchedConds.add(c);
                  allTips.addAll(entry.value);
                }
              }
            }
            if (allTips.isEmpty) {
              allTips.addAll([
                'Eat a variety of colourful vegetables and fruits daily for broad-spectrum nutrients.',
                'Choose whole grains over refined carbs to maintain steady energy throughout the day.',
                'Stay well-hydrated — aim for 8 cups of water daily and limit sugary drinks.',
              ]);
            }
            final displayTips = allTips.take(3).toList();
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(kRadiusLg),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant_rounded, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Diet Tips for Your Conditions 🥗',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                  if (matchedConds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: matchedConds.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(kRadiusFull),
                          border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
                        ),
                        child: Text(c,
                            style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...displayTips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🌿', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(fontSize: 12, color: kText, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          // ── Today's Meals ──────────────────────────────────────────
          const Text(
            "Today's Meals",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kText),
          ),
          const SizedBox(height: 12),
          ...['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
            final meals = state.mealLogs.where((m) {
              final today = DateTime.now();
              return m.mealType.toLowerCase() == type &&
                  m.loggedAt.year == today.year &&
                  m.loggedAt.month == today.month &&
                  m.loggedAt.day == today.day;
            }).toList();

            final emoji = {
              'breakfast': '🌅',
              'lunch': '☀️',
              'dinner': '🌙',
              'snack': '🍎'
            }[type]!;

            final cals =
                meals.fold(0, (sum, m) => sum + (m.calories ?? 0));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border(
                  left: BorderSide(
                    color: meals.isNotEmpty ? kAccent : kBorder,
                    width: 3,
                  ),
                ),
                boxShadow: kCardShadow,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Text(emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: kText),
                ),
                subtitle: Text(
                  meals.isEmpty
                      ? 'Not logged yet'
                      : meals.map((m) => m.description).join(', '),
                  style: TextStyle(
                    fontSize: 11,
                    color: meals.isEmpty ? kTextLight : kSubtext,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: cals > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(kRadiusFull),
                        ),
                        child: Text(
                          '$cals kcal',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }),
          const SizedBox(height: 14),
          // ── Diet tip (condition-aware) ─────────────────────────────
          Builder(builder: (ctx) {
            final conditions = ref.watch(memberProvider).member?.conditions ?? [];
            final tip = _dietTipForConditions(conditions);
            final condLabel = conditions.isNotEmpty ? conditions.first : '';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tips_and_updates_rounded, color: kAccent, size: 15),
                      const SizedBox(width: 6),
                      const Text('Diet Tip',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kAccent)),
                      const Spacer(),
                      if (condLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(kRadiusFull),
                          ),
                          child: Text(condLabel,
                              style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(tip, style: const TextStyle(fontSize: 12, color: kText, height: 1.5)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _calRow(
      String label, String value, String unit, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: kSubtext)),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(fontSize: 10, color: kSubtext),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FitnessTab extends ConsumerStatefulWidget {
  const _FitnessTab();

  @override
  ConsumerState<_FitnessTab> createState() => _FitnessTabState();
}

class _FitnessTabState extends ConsumerState<_FitnessTab> {

  int _stepGoalForConditions(List<String> conditions) {
    final lower = conditions.map((c) => c.toLowerCase()).toList();
    if (lower.any((c) => c.contains('copd') || c.contains('asthma'))) return 4000;
    if (lower.any((c) => c.contains('heart') || c.contains('hypertension') || c.contains('blood pressure'))) return 6000;
    if (lower.any((c) => c.contains('diabetes'))) return 8000;
    if (lower.any((c) => c.contains('hiv') || c.contains('kidney') || c.contains('arthritis'))) return 5000;
    return 10000;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);
    final stepState = ref.watch(stepTrackingProvider);
    final conditions = ref.watch(memberProvider).member?.conditions ?? [];
    final stepGoal = _stepGoalForConditions(conditions);
    final steps = stepState.available ? stepState.dailySteps : state.todaySteps;
    final progress = (steps / stepGoal).clamp(0.0, 1.0);
    final activeMin = state.todayActiveMinutes;
    final calsBurned = stepState.available ? stepState.caloriesBurned : activeMin * 5;
    final fitnessTip = _fitnessConditionTip(conditions);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Live step indicator (when pedometer active) ────────────
          if (stepState.available)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: Color(0xFF16A34A), size: 15),
                  const SizedBox(width: 8),
                  const Text('Live step tracking active',
                      style: TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(kRadiusFull),
                    ),
                    child: const Text('Auto', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          // ── Activity card (Apple Fitness style) ───────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Activity ring
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: kBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                steps >= stepGoal ? kAccent : kPrimary,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatSteps(steps),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: kText,
                                  height: 1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Text(
                                'steps',
                                style:
                                    TextStyle(fontSize: 10, color: kSubtext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Activity stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _activityStat(Icons.directions_walk_rounded,
                              '$steps / $stepGoal', 'Steps', kPrimary),
                          const SizedBox(height: 14),
                          _activityStat(Icons.timer_outlined,
                              '$activeMin min', 'Active Time',
                              const Color(0xFF0891B2)),
                          const SizedBox(height: 14),
                          _activityStat(
                              Icons.local_fire_department_rounded,
                              '$calsBurned kcal',
                              'Burned',
                              kError),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Step goal progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Step Goal',
                          style: TextStyle(
                              fontSize: 11,
                              color: kSubtext,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: steps >= stepGoal ? kAccent : kPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: kBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          steps >= stepGoal ? kAccent : kPrimary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Action buttons ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const FitnessTrackerScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF003DA5), Color(0xFF1A56C4)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003DA5).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Track Activity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(routePartners),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Find Gym'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // ── Weekly chart ───────────────────────────────────────────
          const Text(
            'Weekly Activity',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kText),
          ),
          const SizedBox(height: 12),
          _buildWeeklyChart(state, stepGoal),
          const SizedBox(height: 22),
          // ── Today's Activities ──────────────────────────────────────
          const Text(
            "Today's Activities",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kText),
          ),
          const SizedBox(height: 12),
          ..._buildTodayActivities(state),
          const SizedBox(height: 22),
          // ── Leaderboard ────────────────────────────────────────────
          _buildRankTierCard(state),
          const SizedBox(height: 12),
          _buildLeaderboardCard(state),
          const SizedBox(height: 14),
          // ── Condition-aware fitness tip ────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFEA580C), size: 15),
                    const SizedBox(width: 6),
                    const Text('Fitness Tip',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEA580C))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusFull),
                      ),
                      child: Text(
                        'Goal: $stepGoal steps',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFEA580C), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(fitnessTip, style: const TextStyle(fontSize: 12, color: kText, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTodayActivities(LifestyleState state) {
    final today = DateTime.now();
    final todayLogs = state.fitnessLogs.where((f) =>
        f.loggedAt.year == today.year &&
        f.loggedAt.month == today.month &&
        f.loggedAt.day == today.day).toList();

    if (todayLogs.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadiusMd),
            boxShadow: kCardShadow,
          ),
          child: const Column(
            children: [
              Text('🏃', style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
              Text('No activities logged today',
                  style: TextStyle(fontSize: 13, color: kSubtext)),
              SizedBox(height: 4),
              Text('Track an activity to see it here!',
                  style: TextStyle(fontSize: 11, color: kTextLight)),
            ],
          ),
        ),
      ];
    }

    return todayLogs.map((log) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: const Border(
            left: BorderSide(color: kPrimary, width: 3),
          ),
          boxShadow: kCardShadow,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Text(log.activityEmoji,
              style: const TextStyle(fontSize: 22)),
          title: Text(
            log.activityLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: kText),
          ),
          subtitle: Text(
            [
              '${log.durationMinutes} min',
              if (log.steps != null && log.steps! > 0) '${log.steps} steps',
              if (log.notes != null && log.notes!.isNotEmpty) log.notes!,
            ].join(' • '),
            style: const TextStyle(fontSize: 11, color: kSubtext),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: log.caloriesBurned != null && log.caloriesBurned! > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(kRadiusFull),
                  ),
                  child: Text(
                    '${log.caloriesBurned} kcal',
                    style: const TextStyle(
                      fontSize: 11,
                      color: kError,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
      );
    }).toList();
  }

  /// Returns the tier (name, colours, icon) for a points total.
  static ({String name, String emoji, Color bg, Color border, Color text, String description})
      _tierForPoints(int points) {
    if (points >= 2000) {
      return (
        name: 'Platinum',
        emoji: '💎',
        bg: const Color(0xFFE8F0FE),
        border: const Color(0xFF4F8EF7),
        text: const Color(0xFF1A56C4),
        description: 'Elite performer — top of the pack!',
      );
    } else if (points >= 500) {
      return (
        name: 'Gold',
        emoji: '🥇',
        bg: const Color(0xFFFFFBEB),
        border: const Color(0xFFEAB308),
        text: const Color(0xFF92400E),
        description: 'Outstanding commitment to your health.',
      );
    } else if (points >= 100) {
      return (
        name: 'Silver',
        emoji: '🥈',
        bg: const Color(0xFFF8FAFC),
        border: const Color(0xFF94A3B8),
        text: const Color(0xFF475569),
        description: 'Great progress — keep pushing!',
      );
    } else {
      return (
        name: 'Bronze',
        emoji: '🥉',
        bg: const Color(0xFFFFF7ED),
        border: const Color(0xFFCD7F32),
        text: const Color(0xFF92400E),
        description: 'Just getting started — every step counts!',
      );
    }
  }

  Widget _buildRankTierCard(LifestyleState state) {
    // Find the current user's entry for their total points
    final myEntry = state.leaderboard.where((e) => e.isCurrentUser).firstOrNull;
    final myPoints = myEntry?.totalPoints ?? 0;
    final myRank = state.myRank;
    final tier = _tierForPoints(myPoints);

    // Point thresholds for next tier
    final thresholds = [100, 500, 2000];
    final nextThreshold = thresholds.firstWhere(
      (t) => t > myPoints,
      orElse: () => myPoints,
    );
    final isMaxTier = myPoints >= 2000;
    final progress = isMaxTier
        ? 1.0
        : (myPoints / nextThreshold).clamp(0.0, 1.0);
    final ptsToNext = isMaxTier ? 0 : nextThreshold - myPoints;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tier.bg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: tier.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tier.border.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tier.name} Member',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: tier.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      tier.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: tier.text.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPoints(myPoints),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: tier.text,
                    ),
                  ),
                  Text(
                    'pts',
                    style: TextStyle(
                      fontSize: 10,
                      color: tier.text.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (myRank != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.leaderboard_rounded, size: 13, color: tier.text),
                const SizedBox(width: 4),
                Text(
                  'Your rank: #$myRank this week',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tier.text,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar to next tier
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: tier.border.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(tier.border),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isMaxTier
                    ? 'Max tier 🏆'
                    : '$ptsToNext pts to ${_nextTierName(myPoints)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tier.text.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _nextTierName(int points) {
    if (points < 100) return 'Silver';
    if (points < 500) return 'Gold';
    return 'Platinum';
  }

  Widget _buildLeaderboardCard(LifestyleState state) {
    final entries = state.leaderboard;
    final myRank = state.myRank;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded,
                  color: Color(0xFFEAB308), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Weekly Leaderboard',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kText),
              ),
              const Spacer(),
              if (myRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003DA5), Color(0xFF1A56C4)],
                    ),
                    borderRadius: BorderRadius.circular(kRadiusFull),
                  ),
                  child: Text(
                    'You: #$myRank',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Earn points from fitness, workouts, meals & hydration',
            style: TextStyle(fontSize: 10, color: kSubtext),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No activity yet this week.\nLog a workout, meal or water to earn points!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kSubtext),
                ),
              ),
            )
          else
            ...entries.take(5).map((entry) {
              final isMe = entry.isCurrentUser;
              final rankColor = entry.rank == 1
                  ? const Color(0xFFEAB308)
                  : entry.rank == 2
                      ? const Color(0xFF94A3B8)
                      : entry.rank == 3
                          ? const Color(0xFFCD7F32)
                          : kSubtext;
              final rankIcon = entry.rank <= 3
                  ? ['🥇', '🥈', '🥉'][entry.rank - 1]
                  : null;

              // Build concise breakdown chips
              final chips = <String>[];
              if (entry.activityCount > 0) chips.add('${entry.activityCount} activities');
              if (entry.workoutCount > 0) chips.add('${entry.workoutCount} workouts');
              if (entry.mealCount > 0) chips.add('${entry.mealCount} meals');
              if (entry.waterCups > 0) chips.add('${entry.waterCups} 💧');
              final subtitle = chips.isNotEmpty
                  ? chips.join(' · ')
                  : '${entry.totalMinutes} min';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? kPrimary.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isMe
                      ? Border.all(
                          color: kPrimary.withValues(alpha: 0.2))
                      : null,
                ),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 28,
                      child: rankIcon != null
                          ? Text(rankIcon,
                              style: const TextStyle(fontSize: 16))
                          : Text(
                              '#${entry.rank}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: rankColor,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    // Avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isMe
                          ? kPrimary
                          : kPrimary.withValues(alpha: 0.15),
                      child: Text(
                        entry.name.isNotEmpty
                            ? entry.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white : kPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + breakdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? '${entry.name} (You)' : entry.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isMe ? FontWeight.w700 : FontWeight.w500,
                              color: kText,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                                fontSize: 10, color: kSubtext),
                          ),
                        ],
                      ),
                    ),
                    // Points (primary metric)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatPoints(entry.totalPoints),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kPrimary,
                          ),
                        ),
                        const Text(
                          'pts',
                          style:
                              TextStyle(fontSize: 9, color: kSubtext),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatPoints(int points) {
    if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}k';
    }
    return '$points';
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }

  Widget _activityStat(
      IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: kSubtext),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(LifestyleState state, int stepGoal) {
    final now = DateTime.now();
    final days = List.generate(
        7, (i) => now.subtract(Duration(days: 6 - i)));

    final Map<String, int> dailySteps = {};
    for (final d in days) {
      final key = '${d.year}-${d.month}-${d.day}';
      dailySteps[key] = 0;
    }
    for (final log in state.fitnessLogs) {
      final key =
          '${log.loggedAt.year}-${log.loggedAt.month}-${log.loggedAt.day}';
      if (dailySteps.containsKey(key)) {
        dailySteps[key] = dailySteps[key]! + (log.steps ?? 0);
      }
    }

    final bars = days.asMap().entries.map((e) {
      final key = '${e.value.year}-${e.value.month}-${e.value.day}';
      final steps = dailySteps[key] ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: steps.toDouble(),
            color: steps >= stepGoal ? kAccent : kPrimary,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final maxY = (dailySteps.values.fold(0, (a, b) => a > b ? a : b) * 1.2)
        .clamp(5000.0, double.infinity);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: kBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final idx = v.toInt();
                  return Text(
                    idx < labels.length ? labels[idx] : '',
                    style:
                        const TextStyle(fontSize: 10, color: kSubtext),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }
}

// ── Top-level condition-aware helpers ────────────────────────────────────────

/// Map of condition keyword → diet tips for Feature 1.
const _conditionDietTips = {
  'hypertension': [
    'Limit sodium to under 1,500 mg/day — avoid processed foods, canned soups, and pickles.',
    'Eat potassium-rich foods like bananas, avocados, and sweet potatoes to help lower BP.',
    'Follow the DASH diet: emphasise fruits, vegetables, and whole grains.',
    'Avoid caffeine and alcohol — both can spike blood pressure.',
    'Choose lean proteins: fish, chicken breast, legumes over red meat.',
  ],
  'diabetes': [
    'Choose low-GI foods: oats, legumes, and most vegetables over white rice or bread.',
    'Eat at consistent times daily to stabilise blood sugar levels.',
    'Limit sugary drinks — even fruit juices spike glucose quickly.',
    'Include fibre with every meal to slow glucose absorption.',
    'Control portion sizes — overeating raises blood sugar even with healthy foods.',
  ],
  'heart disease': [
    'Eat omega-3 rich foods: fatty fish (salmon, mackerel), flaxseeds, walnuts.',
    'Avoid trans fats and saturated fats — check labels on packaged foods.',
    'Include soluble fibre (oats, beans, lentils) to lower LDL cholesterol.',
    'Limit red meat — choose fish or plant proteins instead.',
    'Eat colourful vegetables daily for antioxidants that protect the heart.',
  ],
  'heart': [
    'Eat omega-3 rich foods: fatty fish (salmon, mackerel), flaxseeds, walnuts.',
    'Avoid trans fats and saturated fats — check labels on packaged foods.',
    'Include soluble fibre (oats, beans, lentils) to lower LDL cholesterol.',
    'Limit red meat — choose fish or plant proteins instead.',
    'Eat colourful vegetables daily for antioxidants that protect the heart.',
  ],
  'copd': [
    'Eat smaller, more frequent meals — large meals make breathing harder.',
    'Avoid gas-producing foods (beans, cabbage, carbonated drinks) that cause bloating.',
    'Stay well-hydrated to keep mucus thin and easier to clear.',
    'Focus on high-calorie, nutrient-dense foods to maintain weight.',
    'Eat slowly and rest before meals to conserve energy for breathing.',
  ],
  'kidney': [
    'Limit potassium-rich foods: bananas, oranges, potatoes if your kidneys are struggling.',
    'Restrict phosphorus: avoid cola drinks, dairy in excess, and processed foods.',
    'Limit protein intake to reduce kidney workload — consult your dietitian.',
    'Watch sodium carefully — too much causes fluid retention.',
    'Drink the amount of fluid your doctor recommends — not always 8 cups.',
  ],
  'asthma': [
    'Eat antioxidant-rich foods: berries, leafy greens, tomatoes to reduce inflammation.',
    'Include vitamin D sources: eggs, fortified milk — low vitamin D worsens asthma.',
    'Avoid sulfite-containing foods: wine, dried fruits, pickled foods — can trigger attacks.',
    'Maintain a healthy weight — obesity makes asthma significantly worse.',
    'Some asthmatics react to salicylates in apples, berries — track food triggers.',
  ],
  'hiv': [
    'Eat a varied, balanced diet to support immune function.',
    'Include zinc-rich foods: pumpkin seeds, beef, chickpeas — zinc supports immunity.',
    'Ensure adequate protein with every meal: eggs, meat, fish, beans.',
    'Food safety is critical — avoid raw meat, unpasteurised dairy, undercooked eggs.',
    'Take medications with food if they cause nausea.',
  ],
  'arthritis': [
    'Follow an anti-inflammatory diet: olive oil, oily fish, berries, turmeric.',
    'Avoid refined carbohydrates and sugar — they increase inflammation.',
    'Include vitamin C: peppers, citrus fruits — supports cartilage health.',
    'Maintain a healthy weight to reduce pressure on joints.',
    'Ginger and turmeric have anti-inflammatory properties — add to meals or teas.',
  ],
};

/// Returns condition-specific psychosocial recommendations for Feature 3.
List<String> _psychosocialRecs(List<String> conditions, int stressLevel) {
  final recs = <String>[];
  final cLower = conditions.map((c) => c.toLowerCase()).toList();

  if (cLower.any((c) => c.contains('hypertension') || c.contains('heart'))) {
    recs.add('Practice slow breathing (6 breaths/min) — clinically proven to lower BP within minutes.');
    recs.add('Avoid stress-eating salty snacks — your blood pressure is especially sensitive to stress.');
  }
  if (cLower.any((c) => c.contains('diabetes'))) {
    recs.add('Check your blood sugar — stress hormones (cortisol) can spike glucose levels.');
    recs.add('A 10-minute walk can reduce both stress and blood sugar simultaneously.');
  }
  if (cLower.any((c) => c.contains('asthma') || c.contains('copd'))) {
    recs.add('Use pursed-lip breathing during stress — breathe in 2s, out 4s through pursed lips.');
    recs.add('Emotional stress can trigger respiratory symptoms — use the breathing exercise now.');
  }
  if (cLower.any((c) => c.contains('hiv'))) {
    recs.add('Chronic stress weakens immunity. Prioritise rest and social connection today.');
  }
  if (cLower.any((c) => c.contains('arthritis'))) {
    recs.add('Stress increases inflammatory markers — gentle stretching or yoga can help both.');
  }

  recs.addAll([
    'Try the breathing exercise above — 3 rounds of box breathing reduces cortisol.',
    'Talk to someone you trust — isolation worsens stress for chronic illness patients.',
    if (stressLevel >= 8)
      'Your stress level is very high. Please reach out to the helpline or a counsellor.',
  ]);

  return recs.take(4).toList();
}

String _dietTipForConditions(List<String> conditions) {
  final lower = conditions.map((c) => c.toLowerCase()).toList();
  if (lower.any((c) => c.contains('diabetes'))) {
    return 'Choose whole grains, legumes, and non-starchy vegetables. Avoid sugary drinks, white rice, and processed carbs to keep blood sugar steady throughout the day.';
  }
  if (lower.any((c) => c.contains('hypertension') || c.contains('high blood pressure'))) {
    return 'Follow a low-sodium DASH diet. Include more fruits, vegetables, and whole grains. Limit salt to less than 2,300mg/day, avoid cured meats and canned soups.';
  }
  if (lower.any((c) => c.contains('heart'))) {
    return 'Choose heart-healthy fats such as avocado and olive oil. Eat oily fish (salmon, mackerel) twice a week. Limit saturated fats, trans fats, and dietary cholesterol.';
  }
  if (lower.any((c) => c.contains('kidney'))) {
    return 'Limit potassium, phosphorus, and sodium. Avoid high-potassium foods like bananas, oranges, and potatoes. Consult your dietitian for a personalised renal diet plan.';
  }
  if (lower.any((c) => c.contains('copd'))) {
    return 'Eat smaller, more frequent meals to reduce breathlessness after eating. Choose high-protein foods to support respiratory muscle strength. Stay well hydrated.';
  }
  if (lower.any((c) => c.contains('asthma'))) {
    return 'Include antioxidant-rich foods like berries, tomatoes, and leafy greens. Omega-3 fatty acids found in fish and flaxseed may help reduce airway inflammation.';
  }
  if (lower.any((c) => c.contains('obesity'))) {
    return 'Focus on portion control and nutrient-dense foods. Fill half your plate with vegetables and a quarter with lean protein. Avoid sugary drinks and late-night snacking.';
  }
  if (lower.any((c) => c.contains('hiv'))) {
    return 'Maintain a high-protein, balanced diet to support immune function. Eat regularly, ensure adequate calorie intake, and avoid raw or undercooked foods to reduce infection risk.';
  }
  return 'Eat a balanced diet rich in fruits, vegetables, whole grains, and lean proteins. Stay well hydrated and limit processed foods, sugary drinks, and excess salt.';
}

String _psychosocialStressTip(List<String> conditions) {
  final lower = conditions.map((c) => c.toLowerCase()).toList();
  if (lower.any((c) => c.contains('hypertension') || c.contains('high blood pressure'))) {
    return 'High stress raises blood pressure directly. Try slow diaphragmatic breathing below (4s in, 4s hold, 4s out). Limit caffeine and avoid confrontational situations until you feel calmer. Contact your care team if you feel a severe headache.';
  }
  if (lower.any((c) => c.contains('diabetes'))) {
    return 'Stress hormones like cortisol can raise blood sugar. Check your glucose now, stay hydrated, take a short 10-minute walk, and avoid stress-eating sugary or processed foods.';
  }
  if (lower.any((c) => c.contains('heart'))) {
    return 'Stress places extra load on your heart. Rest immediately, use the breathing exercise below, and call your doctor if you feel chest pain, palpitations, or shortness of breath.';
  }
  if (lower.any((c) => c.contains('asthma'))) {
    return 'Anxiety can trigger airway tightening. Breathe slowly through your nose, stay warm, keep your rescue inhaler accessible, and avoid physical exertion until you feel calmer.';
  }
  if (lower.any((c) => c.contains('copd'))) {
    return 'Stress worsens breathlessness. Sit upright in a relaxed position, use pursed-lip breathing (inhale through nose, exhale through pursed lips), and contact your care team if symptoms worsen.';
  }
  if (lower.any((c) => c.contains('hiv'))) {
    return 'Chronic stress weakens the immune system. Prioritise sleep, connect with a trusted friend or counsellor, and consider joining a peer support group for people living with HIV.';
  }
  return 'Try 5 minutes of deep breathing below, take a short walk outdoors, or call the Sanlam support line above. Remember: asking for help is a sign of strength.';
}

String _fitnessConditionTip(List<String> conditions) {
  final lower = conditions.map((c) => c.toLowerCase()).toList();
  if (lower.any((c) => c.contains('hypertension') || c.contains('blood pressure'))) {
    return 'Moderate activity like brisk walking significantly lowers blood pressure. Avoid sudden intense bursts of exercise — keep a comfortable, steady pace and monitor how you feel.';
  }
  if (lower.any((c) => c.contains('diabetes'))) {
    return 'Exercise helps cells absorb glucose more effectively. Aim for 30 minutes of moderate activity daily. Monitor blood sugar before and after activity and carry a fast-acting snack.';
  }
  if (lower.any((c) => c.contains('heart'))) {
    return 'Cardiac-safe exercise improves heart function over time. Focus on light-to-moderate intensity — walking, swimming, or cycling. Stop immediately if you feel chest pain or dizziness.';
  }
  if (lower.any((c) => c.contains('copd'))) {
    return 'Short, frequent walks build breathing muscle strength. Never overexert yourself — rest when breathing becomes difficult, and always keep your inhaler within reach during exercise.';
  }
  if (lower.any((c) => c.contains('asthma'))) {
    return 'Always warm up for at least 10 minutes before exercising. Breathe through your nose to filter and warm air. Avoid outdoor exercise on high-pollen or cold, dry days.';
  }
  if (lower.any((c) => c.contains('hiv'))) {
    return 'Regular moderate exercise supports immune function and mental wellbeing. Avoid overtraining — rest days are just as important as active days for recovery.';
  }
  if (lower.any((c) => c.contains('obesity'))) {
    return 'Start with low-impact activities like walking or swimming. Gradually increase duration before intensity. Consistency matters more than intensity — even 20 minutes a day makes a difference.';
  }
  return 'Aim for at least 30 minutes of moderate activity daily. A brisk walk, cycling, or swimming all count. Consistency over time is more important than intensity.';
}
