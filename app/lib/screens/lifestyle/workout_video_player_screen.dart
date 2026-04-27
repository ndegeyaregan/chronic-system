import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/lifestyle_provider.dart';

const _kBg   = Color(0xFFF2F2F2);
const _kCard = Colors.white;
const _kDark = Color(0xFF1C1C1E);
const _kGrey = Color(0xFF8E8E93);
const _kBlue = Color(0xFF003DA5);

const _kDescriptions = {
  'Cardio':     'Get your heart rate up and burn calories with this energising cardio session designed to improve cardiovascular health and endurance.',
  'HIIT':       'High-intensity intervals to maximise calorie burn in minimal time. Alternating bursts of effort with short recovery periods.',
  'Strength':   'Build lean muscle and increase metabolism with progressive strength exercises. Focus on form and controlled movement.',
  'Yoga':       'Combine breath control and mindful movement to strengthen the body and calm the mind. Suitable for all fitness levels.',
  'Stretching': 'Improve flexibility, reduce injury risk and speed up recovery with this guided stretching routine.',
};

const _kCalPerMin = {'Cardio': 8, 'HIIT': 12, 'Strength': 6, 'Yoga': 4, 'Stretching': 3};

class WorkoutVideoPlayerScreen extends ConsumerStatefulWidget {
  final Map<String, String> workout;
  final List<Map<String, String>> related;
  const WorkoutVideoPlayerScreen({super.key, required this.workout, required this.related});

  @override
  ConsumerState<WorkoutVideoPlayerScreen> createState() => _WorkoutVideoPlayerScreenState();
}

class _WorkoutVideoPlayerScreenState extends ConsumerState<WorkoutVideoPlayerScreen> {
  YoutubePlayerController? _ytController;
  bool _expanded    = false;
  bool _isRunning   = false;
  bool _saved       = false;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;
  Timer?    _ticker;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: widget.workout['videoId']!,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          origin: 'https://www.youtube-nocookie.com',
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ytController?.close();
    super.dispose();
  }

  void _openInYouTube(String videoId) {
    launchUrl(
      Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _startWorkout() {
    setState(() {
      _isRunning = true;
      _saved     = false;
      _startTime = DateTime.now();
      _elapsed   = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startTime!));
    });
  }

  Future<void> _stopAndSave() async {
    _ticker?.cancel();
    final minutes = _elapsed.inMinutes < 1 ? 1 : _elapsed.inMinutes;
    setState(() { _isRunning = false; });

    final cat      = widget.workout['category']!;
    final calories = (_kCalPerMin[cat] ?? 6) * minutes;

    final ok = await ref.read(lifestyleProvider.notifier).logFitness({
      'activity_type':     cat,
      'duration_minutes':  minutes,
      'calories_burned':   calories,
      'notes':             'Completed: ${widget.workout['title']} via Workouts',
    });

    setState(() => _saved = ok);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Workout saved! $minutes min \u2022 $calories kcal logged'
            : 'Could not save workout. Please try again.'),
        backgroundColor: ok ? const Color(0xFF34C759) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _fmt(Duration d) {
    final h  = d.inHours;
    final m  = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final w    = widget.workout;
    final cat  = w['category']!;
    final diff = w['difficulty']!;
    final desc = _kDescriptions[cat] ?? 'A great workout to improve your fitness and overall health.';
    final shortDesc = desc.length > 100 ? '${desc.substring(0, 100)}...' : desc;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Program details',
            style: TextStyle(color: _kDark, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded, color: _kDark, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Card 1: Thumbnail + info ────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: kIsWeb
                          ? _VideoThumb(
                              videoId: w['videoId']!,
                              category: cat,
                              onPlay: () => _openInYouTube(w['videoId']!),
                            )
                          : YoutubePlayer(controller: _ytController!, aspectRatio: 16 / 9),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w['title']!,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kDark, height: 1.3)),
                        const SizedBox(height: 10),
                        Text(_expanded ? desc : shortDesc,
                            style: const TextStyle(fontSize: 14, color: _kGrey, height: 1.5)),
                        if (desc.length > 100) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(() => _expanded = !_expanded),
                            child: Text(_expanded ? 'View less' : 'View more',
                                style: const TextStyle(fontSize: 14, color: _kDark,
                                    fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          const Text('Powered by ', style: TextStyle(fontSize: 13, color: _kGrey)),
                          Text(w['channel']!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _openInYouTube(w['videoId']!),
                            child: const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
                          ),
                        ]),
                        if (!kIsWeb) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _openInYouTube(w['videoId']!),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.open_in_new_rounded, size: 14, color: _kBlue),
                              SizedBox(width: 4),
                              Text('Open in YouTube app',
                                  style: TextStyle(fontSize: 13, color: _kBlue, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Card 2: Program overview ────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Program overview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Column(children: [
                      Text(diff, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kDark)),
                      const SizedBox(height: 4),
                      const Text('Difficulty', style: TextStyle(fontSize: 13, color: _kGrey)),
                    ])),
                    Container(width: 1, height: 48, color: const Color(0xFFE5E5E5)),
                    Expanded(child: Column(children: [
                      Text(w['duration']!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kDark)),
                      const SizedBox(height: 4),
                      const Text('Duration', style: TextStyle(fontSize: 13, color: _kGrey)),
                    ])),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Equipment', style: TextStyle(fontSize: 14, color: _kGrey)),
                    Expanded(child: _DottedLine()),
                    const Text('Not required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Text('Program category', style: TextStyle(fontSize: 14, color: _kGrey)),
                    Expanded(child: _DottedLine()),
                    Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Workout timer card (shows when running) ─────────────────────
            if (_isRunning || _saved) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _isRunning ? _kBlue : const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(children: [
                  Icon(_isRunning ? Icons.timer_rounded : Icons.check_circle_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isRunning ? 'Workout in progress' : 'Workout saved!',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (_isRunning)
                      Text(_fmt(_elapsed),
                          style: const TextStyle(color: Colors.white70, fontSize: 28,
                              fontWeight: FontWeight.w800, letterSpacing: 2)),
                    if (_saved && !_isRunning)
                      Text('${_elapsed.inMinutes < 1 ? 1 : _elapsed.inMinutes} min \u2022 '
                          '${(_kCalPerMin[cat] ?? 6) * (_elapsed.inMinutes < 1 ? 1 : _elapsed.inMinutes)} kcal logged',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Related workouts ────────────────────────────────────────────
            if (widget.related.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  const Expanded(child: Text('More Workouts',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kDark))),
                  const Icon(Icons.chevron_right_rounded, color: _kDark, size: 24),
                ]),
              ),
              ...widget.related.map((rw) => _RelatedCard(workout: rw, onTap: () {
                _ytController?.loadVideo(rw['videoId']!);
              })),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),

      // ── Start / Stop workout button ─────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: _isRunning
                ? ElevatedButton.icon(
                    onPressed: _stopAndSave,
                    icon: const Icon(Icons.stop_rounded, size: 22),
                    label: Text('Stop \u2022 ${_fmt(_elapsed)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _startWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E5EA),
                      foregroundColor: _kDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: const Text('Start workout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Video thumbnail with play button ──────────────────────────────────────────

class _VideoThumb extends StatelessWidget {
  final String videoId;
  final String category;
  final VoidCallback onPlay;
  const _VideoThumb({required this.videoId, required this.category, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Stack(fit: StackFit.expand, children: [
        Image.network(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFE0E0E0),
            child: Center(child: Icon(_catIcon(), color: const Color(0xFFAAAAAA), size: 52)),
          ),
          loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE0E0E0)),
        ),
        Center(
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
        ),
        Positioned(
          left: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Watch on YouTube',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  IconData _catIcon() {
    switch (category) {
      case 'Cardio':     return Icons.directions_run_rounded;
      case 'HIIT':       return Icons.flash_on_rounded;
      case 'Strength':   return Icons.fitness_center_rounded;
      case 'Yoga':       return Icons.self_improvement_rounded;
      case 'Stretching': return Icons.accessibility_new_rounded;
      default:           return Icons.sports_rounded;
    }
  }
}

// ── Related card ──────────────────────────────────────────────────────────────

class _RelatedCard extends StatelessWidget {
  final Map<String, String> workout;
  final VoidCallback onTap;
  const _RelatedCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 90, height: 68,
              child: Stack(fit: StackFit.expand, children: [
                Image.network(
                  'https://img.youtube.com/vi/${workout['videoId']}/hqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE5E5E5),
                      child: const Center(child: Icon(Icons.fitness_center_rounded, color: Color(0xFFAAAAAA), size: 28))),
                  loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE5E5E5)),
                ),
                const Positioned(left: 6, bottom: 6, child: _YtSmall()),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(workout['title']!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${workout['duration']!}  \u2022  ${workout['channel']!}',
                style: const TextStyle(fontSize: 12, color: _kGrey),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
        ]),
      ),
    );
  }
}

class _YtSmall extends StatelessWidget {
  const _YtSmall();
  @override
  Widget build(BuildContext context) => Container(
    width: 22, height: 16,
    decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(3)),
    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
  );
}

// ── Dotted line spacer ────────────────────────────────────────────────────────

class _DottedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(builder: (_, c) {
        final count = (c.maxWidth / 6).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(count,
              (_) => const SizedBox(width: 3, height: 1,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFDDDDDD))))),
        );
      }),
    );
  }
}
