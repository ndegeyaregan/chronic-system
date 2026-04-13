import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pedometer/pedometer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/lifestyle_provider.dart';
import '../../providers/vitals_provider.dart';
import 'workout_videos_section.dart';

class FitnessTrackerScreen extends ConsumerStatefulWidget {
  const FitnessTrackerScreen({super.key});

  @override
  ConsumerState<FitnessTrackerScreen> createState() =>
      _FitnessTrackerScreenState();
}

class _FitnessTrackerScreenState extends ConsumerState<FitnessTrackerScreen>
    with TickerProviderStateMixin {

  // ── Activity data ─────────────────────────────────────────────────────────
  int _selectedActivity = 0;
  final _activities = [
    {
      'key': 'walking',
      'label': 'Walking',
      'icon': Icons.directions_walk_rounded,
      'met': 3.5,
      'intro': 'Walking is a great low-impact exercise. Stand tall, swing your arms naturally, and keep a steady pace.',
      'cues': [
        'Good rhythm. Keep your chin up and look ahead.',
        'Breathe in for 3 steps, breathe out for 3 steps.',
        'Great pace! Engage your core as you walk.',
        'You are doing amazing. Stay consistent.',
        'Halfway through. Keep that stride strong.',
        'Pick up the pace slightly if you can.',
        'Almost there. Finish strong!',
      ],
    },
    {
      'key': 'running',
      'label': 'Running',
      'icon': Icons.directions_run_rounded,
      'met': 8.0,
      'intro': 'Running builds endurance and burns calories fast. Land mid-foot, keep your body slightly forward, and breathe rhythmically.',
      'cues': [
        'Keep your shoulders relaxed, arms at 90 degrees.',
        'Breathe in for 2 strides, out for 2 strides.',
        'Great form! Drive your knees forward.',
        'Maintain this pace. You are doing great.',
        'Push through. Your body is stronger than you think.',
        'Final stretch. Dig deep and finish strong!',
      ],
    },
    {
      'key': 'cycling',
      'label': 'Cycling',
      'icon': Icons.directions_bike_rounded,
      'met': 6.0,
      'intro': 'Cycling is excellent for your legs and heart. Keep a steady cadence and stay seated unless climbing.',
      'cues': [
        'Keep your back straight and grip relaxed.',
        'Maintain a smooth, circular pedal motion.',
        'Great cadence! Push through the downstroke.',
        'Stay hydrated. Take a sip if you have water nearby.',
        'Increase resistance slightly to challenge yourself.',
        'Excellent effort. Keep that rhythm going.',
      ],
    },
    {
      'key': 'swimming',
      'label': 'Swimming',
      'icon': Icons.pool_rounded,
      'met': 6.0,
      'intro': 'Swimming works every muscle group. Focus on your breathing technique and keep your body horizontal.',
      'cues': [
        'Keep your hips high and body flat in the water.',
        'Exhale fully underwater for efficient breathing.',
        'Great stroke! Reach long with each arm pull.',
        'Turn your head smoothly to breathe, not lift it.',
        'Fantastic effort. Stay smooth and controlled.',
      ],
    },
    {
      'key': 'gym',
      'label': 'Gym',
      'icon': Icons.fitness_center_rounded,
      'met': 5.0,
      'intro': 'Gym training builds strength and muscle. Focus on form over weight. Control every rep.',
      'cues': [
        'Warm up properly before heavy sets.',
        'Control the movement. Slow down the eccentric phase.',
        'Rest 60 to 90 seconds between sets.',
        'Stay focused. Mind-muscle connection matters.',
        'Great session! Hydrate between exercises.',
        'Push your last set to near failure safely.',
      ],
    },
    {
      'key': 'rope_skipping',
      'label': 'Jump Rope',
      'icon': Icons.sports_gymnastics_rounded,
      'met': 12.0,
      'intro': 'Jump rope is a full-body cardio burner. Stay on your toes, keep jumps small, and maintain a steady rhythm.',
      'cues': [
        'Land softly on the balls of your feet.',
        'Keep your elbows close to your body.',
        'Breathe steadily. Do not hold your breath.',
        'Excellent rhythm! You are burning serious calories.',
        'Take a 30-second rest if you need it, then continue.',
        'Final round. Give it everything you have!',
      ],
    },
    {
      'key': 'yoga',
      'label': 'Yoga',
      'icon': Icons.self_improvement_rounded,
      'met': 2.5,
      'intro': 'Yoga connects mind and body. Move slowly, breathe deeply, and never force a position beyond your comfort.',
      'cues': [
        'Breathe in deeply through your nose.',
        'Exhale slowly and let your body soften into the pose.',
        'Close your eyes and focus inward.',
        'Release any tension in your shoulders.',
        'You are doing beautifully. Stay present.',
        'Scan your body for any areas of tightness and breathe into them.',
      ],
    },
    {
      'key': 'other',
      'label': 'Other',
      'icon': Icons.sports_rounded,
      'met': 4.0,
      'intro': 'Every movement counts. Stay hydrated, listen to your body, and enjoy your session.',
      'cues': [
        'Focus on your breathing.',
        'Stay consistent and keep moving.',
        'Great effort! You are doing well.',
        'Listen to your body and adjust intensity as needed.',
        'Keep pushing. Every second counts.',
        'Finish strong. You have got this!',
      ],
    },
  ];

  // ── Timer state ────────────────────────────────────────────────────────────
  Timer? _timer;
  Timer? _instructorTimer;
  int _elapsedSeconds = 0;
  bool _timerRunning = false;
  int _cueIndex = 0;
  String _instructorText = '';
  bool _voiceEnabled = true;

  // ── Native TTS ─────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();

  // ── Auto-tracking: steps (pedometer) + distance (GPS) ─────────────────────
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<Position>? _positionSub;
  int _latestTotalSteps = 0;
  int _sessionStartSteps = 0;
  int _liveSteps = 0;
  double _liveDistanceM = 0;
  Position? _lastPosition;
  bool _trackingActive = false;

  // ── Input controllers ──────────────────────────────────────────────────────
  final _stepsCtrl    = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _ringAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );
    _instructorText = _activities[_selectedActivity]['intro'] as String;
    _initTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _instructorTimer?.cancel();
    _stepSub?.cancel();
    _positionSub?.cancel();
    _tabController.dispose();
    _ringController.dispose();
    _stepsCtrl.dispose();
    _durationCtrl.dispose();
    _caloriesCtrl.dispose();
    _distanceCtrl.dispose();
    _notesCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Native TTS ─────────────────────────────────────────────────────────────
  Future<void> _speak(String text) async {
    if (!_voiceEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  void _cancelSpeech() => _tts.stop();

  // ── Tracking initialisation ────────────────────────────────────────────────
  Future<void> _initTracking() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.05);
    await _tts.setVolume(1.0);

    await _requestPermissions();
    _startStepTracking();
    _startGpsTracking();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return; // Permissions not applicable on web
    // Location permission
    LocationPermission loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.denied) {
      loc = await Geolocator.requestPermission();
    }
    // Activity recognition (Android 10+ / iOS)
    final motionStatus = await Permission.activityRecognition.status;
    if (motionStatus.isDenied) {
      await Permission.activityRecognition.request();
    }
  }

  void _startStepTracking() {
    if (kIsWeb) return; // Pedometer is not supported on web
    try {
      _stepSub = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (mounted) {
            setState(() {
              _latestTotalSteps = event.steps;
              if (_timerRunning && _sessionStartSteps > 0) {
                _liveSteps = (event.steps - _sessionStartSteps).clamp(0, 999999);
              }
            });
          }
        },
        onError: (e) => debugPrint('Pedometer: $e'),
        cancelOnError: false,
      );
      if (mounted) setState(() => _trackingActive = true);
    } catch (e) {
      debugPrint('Step tracking unavailable: $e');
    }
  }

  void _startGpsTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
    try {
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position pos) {
          if (_lastPosition != null && _timerRunning) {
            final d = Geolocator.distanceBetween(
              _lastPosition!.latitude, _lastPosition!.longitude,
              pos.latitude, pos.longitude,
            );
            if (d > 1.5 && d < 80) {
              if (mounted) setState(() => _liveDistanceM += d);
            }
          }
          _lastPosition = pos;
        },
        onError: (e) => debugPrint('GPS: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('GPS tracking unavailable: $e');
    }
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────
  void _startTimer() {
    final act = _activities[_selectedActivity];
    final intro = act['intro'] as String;
    setState(() {
      _timerRunning = true;
      _cueIndex = 0;
      _instructorText = intro;
      // Snapshot step counter so we measure only this session
      _sessionStartSteps = _latestTotalSteps;
      _liveSteps = 0;
      _liveDistanceM = 0;
      _lastPosition = null;
    });
    _ringController.repeat(reverse: true);
    _speak(intro);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // Cue every 90 seconds
    _instructorTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      final cues = act['cues'] as List<String>;
      if (_cueIndex < cues.length) {
        setState(() => _instructorText = cues[_cueIndex]);
        _speak(cues[_cueIndex]);
        _cueIndex++;
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _instructorTimer?.cancel();
    final minutes = (_elapsedSeconds / 60).ceil().clamp(1, 999);
    final distKm   = _liveDistanceM / 1000;
    final stepsTxt = _liveSteps > 0 ? '$_liveSteps steps' : '';
    final distTxt  = distKm > 0 ? '${distKm.toStringAsFixed(2)} km' : '';
    final extra    = [stepsTxt, distTxt].where((s) => s.isNotEmpty).join(' and ');
    final msg      = extra.isNotEmpty
        ? 'Well done! $minutes minutes logged. You covered $extra. Tap Save to record your session.'
        : 'Well done! $minutes minutes logged. Tap Save Activity to record your session.';
    final autoCalories = _calcCalories(seconds: _elapsedSeconds);
    setState(() {
      _timerRunning = false;
      _durationCtrl.text = minutes.toString();
      _instructorText = msg;
      if (_liveSteps > 0)     _stepsCtrl.text    = '$_liveSteps';
      if (_liveDistanceM > 0) _distanceCtrl.text = distKm.toStringAsFixed(2);
      if (autoCalories > 0)   _caloriesCtrl.text = '$autoCalories';
    });
    _ringController.stop();
    _speak(msg);
  }

  void _resetTimer() {
    _timer?.cancel();
    _instructorTimer?.cancel();
    _cancelSpeech();
    final intro = _activities[_selectedActivity]['intro'] as String;
    setState(() {
      _timerRunning = false;
      _elapsedSeconds = 0;
      _durationCtrl.clear();
      _stepsCtrl.clear();
      _distanceCtrl.clear();
      _instructorText = intro;
      _cueIndex = 0;
      _liveSteps = 0;
      _liveDistanceM = 0;
      _sessionStartSteps = 0;
      _lastPosition = null;
    });
    _ringController.stop();
  }

  void _onActivityChanged(int index) {
    if (_timerRunning) return;
    setState(() {
      _selectedActivity = index;
      _instructorText = _activities[index]['intro'] as String;
    });
  }

  String get _timerDisplay {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // ── MET-based calorie calculation ─────────────────────────────────────────
  // Formula: Calories = MET × weight_kg × duration_hours
  int _calcCalories({int? seconds}) {
    final weight = ref.read(vitalsProvider).latest?.weight ?? 70.0;
    final met    = (_activities[_selectedActivity]['met'] as double);
    final hours  = (seconds ?? _elapsedSeconds) / 3600.0;
    if (hours <= 0) return 0;
    return (met * weight * hours).round();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_durationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set a duration — use the timer or enter manually.'),
          backgroundColor: kWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final success = await ref.read(lifestyleProvider.notifier).logFitness({
      'activity_type': _activities[_selectedActivity]['key'],
      if (_stepsCtrl.text.isNotEmpty) 'steps': int.tryParse(_stepsCtrl.text),
      'duration_minutes': int.tryParse(_durationCtrl.text) ?? 0,
      if (_distanceCtrl.text.isNotEmpty)
        'distance_km': double.tryParse(_distanceCtrl.text),
      if (_caloriesCtrl.text.isNotEmpty)
        'calories_burned': int.tryParse(_caloriesCtrl.text),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
    });

    if (success && mounted) {
      _speak('Activity saved! Great work today!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Activity saved! Great work! 💪'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003DA5),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () {
            _tts.stop();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Fitness',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 0
                ? IconButton(
                    icon: Icon(
                      _voiceEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _voiceEnabled
                          ? Colors.white
                          : Colors.white38,
                      size: 22,
                    ),
                    tooltip: _voiceEnabled
                        ? 'Mute instructor'
                        : 'Enable instructor',
                    onPressed: () {
                      setState(() => _voiceEnabled = !_voiceEnabled);
                      if (!_voiceEnabled) _tts.stop();
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF003DA5),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(
                  icon: Icon(Icons.timer_rounded, size: 18),
                  text: 'Track',
                ),
                Tab(
                  icon: Icon(Icons.play_circle_outline_rounded, size: 18),
                  text: 'Workouts',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Tracking ──────────────────────────────────────────
          _buildTrackingTab(state),
          // ── Tab 1: Workout Videos ────────────────────────────────────
          _buildWorkoutsTab(),
        ],
      ),
      bottomNavigationBar: const _FitnessNav(),
    );
  }

  // ── Tracking tab content ───────────────────────────────────────────────────
  Widget _buildTrackingTab(LifestyleState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── 1. Activity type selector ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _activities.length,
                itemBuilder: (_, i) {
                  final a = _activities[i];
                  final selected = _selectedActivity == i;
                  return GestureDetector(
                    onTap: () => _onActivityChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF003DA5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        border: selected
                            ? null
                            : Border.all(
                                color: const Color(0xFFDDDDDD), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            a['icon'] as IconData,
                            size: 18,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF003DA5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            a['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF003DA5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 2. Coach panel ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: Color(0xFF003DA5), size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'COACH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003DA5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _speak(_instructorText),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEEEEE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Color(0xFF003DA5), size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _instructorText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3A3A3C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 3. Timer card ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (_, child) {
                    final scale = _timerRunning ? _ringAnimation.value : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _timerRunning
                            ? const Color(0xFF003DA5)
                            : const Color(0xFFEEEEEE),
                        width: _timerRunning ? 3 : 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timerDisplay,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w200,
                              color: _timerRunning
                                  ? const Color(0xFF003DA5)
                                  : const Color(0xFFAEAEB2),
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timerRunning ? 'RECORDING' : 'READY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _timerRunning
                                  ? const Color(0xFF003DA5)
                                  : const Color(0xFFAEAEB2),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                if (!_timerRunning) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'Start Workout',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003DA5),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_elapsedSeconds > 0) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resetTimer,
                      child: const Text('Reset',
                          style: TextStyle(
                              color: Color(0xFF888888), fontSize: 14)),
                    ),
                  ],
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop_rounded, size: 22),
                      label: const Text(
                        'Stop & Save',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003DA5),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],

                if (_elapsedSeconds > 0 && !_timerRunning)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF003DA5), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '✓ Duration saved: ${_durationCtrl.text} min',
                          style: const TextStyle(
                            color: Color(0xFF003DA5),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 4. Stats row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AUTO-TRACKED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003DA5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _trackingActive
                            ? const Color(0xFF003DA5)
                            : const Color(0xFFAEAEB2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _trackingActive
                          ? 'GPS + Motion Active'
                          : 'Starting...',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF888888)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statTile(
                      label: 'Steps',
                      value: _liveSteps > 0 ? '$_liveSteps' : '--',
                      icon: Icons.directions_walk_rounded,
                      live: _timerRunning,
                    ),
                    const SizedBox(width: 8),
                    _statTile(
                      label: 'Distance',
                      value: _liveDistanceM > 0
                          ? '${(_liveDistanceM / 1000).toStringAsFixed(2)} km'
                          : '--',
                      icon: Icons.straighten_rounded,
                      live: _timerRunning,
                    ),
                    const SizedBox(width: 8),
                    _statTile(
                      label: 'Calories',
                      value: _elapsedSeconds > 0
                          ? '${_calcCalories()} kcal'
                          : '--',
                      icon: Icons.local_fire_department_rounded,
                      live: _timerRunning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 5. Log Details ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003DA5),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _cleanInput(
                        controller: _durationCtrl,
                        label: 'Duration (min)',
                        hint: 'e.g. 30',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cleanInput(
                        controller: _stepsCtrl,
                        label: 'Steps (auto-filled)',
                        hint: 'e.g. 5000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _cleanInput(
                        controller: _distanceCtrl,
                        label: 'Distance (km, auto)',
                        hint: 'e.g. 2.50',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cleanInput(
                        controller: _caloriesCtrl,
                        label: 'Calories (auto-calc)',
                        hint: _elapsedSeconds > 0
                            ? 'Auto: ~${_calcCalories()} kcal'
                            : 'e.g. 250',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _cleanInput(
                  controller: _notesCtrl,
                  label: 'Notes (optional)',
                  hint: 'How did it feel?',
                  maxLines: 2,
                ),
              ],
            ),
          ),

          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(state.error!,
                  style: const TextStyle(color: kError, fontSize: 13)),
            ),

          // ── 6. Save button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD1D1D6),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text(
                        'Save Activity',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Workouts tab content ───────────────────────────────────────────────────
  Widget _buildWorkoutsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: WorkoutVideosSection(),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────
  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    bool live = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
          ],
          border: live
              ? Border.all(
                  color: const Color(0xFF003DA5).withValues(alpha: 0.3),
                  width: 1)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: live
                    ? const Color(0xFF003DA5)
                    : const Color(0xFF888888)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: live
                    ? const Color(0xFF003DA5)
                    : const Color(0xFF003DA5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cleanInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 15,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: Color(0xFF6E6E73), fontSize: 13),
        hintStyle:
            const TextStyle(color: Color(0xFFAEAEB2), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}


// ── Standalone bottom nav (avoids GoRouterState which requires ShellRoute context) ──

class _FitnessNav extends StatelessWidget {
  const _FitnessNav();

  static const _items = [
    (icon: Icons.home_rounded,            label: 'Home',         color: Color(0xFF007AFF), route: routeDashboard),
    (icon: Icons.favorite_rounded,         label: 'Health',       color: Color(0xFFFF3B30), route: routeVitals),
    (icon: Icons.calendar_month_rounded,   label: 'Appointments', color: Color(0xFF32ADE6), route: routeAppointments),
    (icon: Icons.self_improvement_rounded, label: 'Lifestyle',    color: Color(0xFF34C759), route: routeLifestyle),
    (icon: Icons.person_rounded,           label: 'Profile',      color: Color(0xFFFF9500), route: routeProfile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item     = _items[i];
              final isActive = i == 3; // Lifestyle is always active here
              final col      = item.color;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isActive) context.go(item.route);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? col.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 22, color: isActive ? col : col.withValues(alpha: 0.38)),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Text(item.label,
                            style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
