import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'workout_video_player_screen.dart';

// ── Workout data ───────────────────────────────────────────────────────────────
const _kWorkouts = [
  {'videoId':'UBMk30rjy0o','title':'30-Min Full Body Cardio Blast','channel':'FitnessBlender','duration':'30 min','difficulty':'Beginner','category':'Cardio'},
  {'videoId':'ml6cT4AZdqI','title':'10-Min Ab Blast','channel':'Chloe Ting','duration':'10 min','difficulty':'Intermediate','category':'Strength'},
  {'videoId':'v7AYKMP6rOE','title':'Yoga for Complete Beginners','channel':'Yoga With Adriene','duration':'20 min','difficulty':'Beginner','category':'Yoga'},
  {'videoId':'MKmrqcoCZ-M','title':'30-Min Full Body HIIT','channel':'Heather Robertson','duration':'30 min','difficulty':'Intermediate','category':'HIIT'},
  {'videoId':'sTANio_2E0Q','title':'Full Body Stretch Routine','channel':'MommaStrong','duration':'15 min','difficulty':'Beginner','category':'Stretching'},
  {'videoId':'vc1E5CfRfos','title':'30-Min Strength Training','channel':'FitnessBlender','duration':'30 min','difficulty':'Intermediate','category':'Strength'},
  {'videoId':'cbKkB3POqaY','title':'Morning Cardio Kickstart','channel':'POPSUGAR Fitness','duration':'25 min','difficulty':'Beginner','category':'Cardio'},
  {'videoId':'TkaYafQ-XC4','title':'HIIT for Fat Loss – Full Body','channel':'Heather Robertson','duration':'35 min','difficulty':'Advanced','category':'HIIT'},
  {'videoId':'4pKly2JojMw','title':'Jump Rope Cardio Burn','channel':'Jump Rope Dudes','duration':'20 min','difficulty':'Intermediate','category':'Cardio'},
  {'videoId':'RqcOCBb4arc','title':'Morning Yoga Flow','channel':'Yoga With Adriene','duration':'30 min','difficulty':'Beginner','category':'Yoga'},
];

const _kBlue = Color(0xFF003DA5);

const _kFilters = ['All', 'Cardio', 'HIIT', 'Strength', 'Yoga', 'Stretching'];

void _openVideo(BuildContext context, Map<String, String> workout) {
  final related = _kWorkouts
      .where((w) => w['videoId'] != workout['videoId'] && w['category'] == workout['category'])
      .cast<Map<String, String>>()
      .toList();
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => WorkoutVideoPlayerScreen(workout: workout, related: related)),
  );
}

// ── Main widget ───────────────────────────────────────────────────────────────

class WorkoutVideosSection extends StatefulWidget {
  const WorkoutVideosSection({super.key});

  @override
  State<WorkoutVideosSection> createState() => _WorkoutVideosSectionState();
}

class _WorkoutVideosSectionState extends State<WorkoutVideosSection> {
  String _filter = 'All';

  List<Map<String, String>> get _filtered {
    if (_filter == 'All') return List.castFrom(_kWorkouts);
    return _kWorkouts.where((w) => w['category'] == _filter).cast<Map<String, String>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered  = _filtered;
    final whatsNew  = filtered.take(6).toList();
    final featured  = filtered.length > 3 ? filtered.skip(3).take(4).toList() : filtered.take(4).toList();

    return ColoredBox(
      color: context.c.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── Filter chips ───────────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kFilters.length,
              itemBuilder: (_, i) {
                final f = _kFilters[i];
                final active = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _kBlue : context.c.cardBg,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: active
                          ? [const BoxShadow(color: Color(0x33003DA5), blurRadius: 6, offset: Offset(0, 2))]
                          : [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                    child: Text(f,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : context.c.subtext,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Section: What's new ────────────────────────────────────────────
          if (whatsNew.isNotEmpty) ...[
            _SectionHeader(title: "What's new", onMore: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 216,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: whatsNew.length,
                itemBuilder: (_, i) => _SmallCard(
                  workout: whatsNew[i],
                  onTap: () => _openVideo(context, whatsNew[i]),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Section: Featured programs ─────────────────────────────────────
          if (featured.isNotEmpty) ...[
            _SectionHeader(title: 'Your Home, Your Gym \u2013 Train Like a Pro', onMore: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: featured.length,
                itemBuilder: (_, i) => _LargeCard(
                  workout: featured[i],
                  onTap: () => _openVideo(context, featured[i]),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (whatsNew.isEmpty && featured.isEmpty) ...[
            const SizedBox(height: 60),
            Center(
              child: Column(children: [
                Icon(_filterIcon(_filter), color: context.c.subtext, size: 48),
                const SizedBox(height: 12),
                Text('No $_filter workouts yet', style: TextStyle(fontSize: 16, color: context.c.subtext)),
              ]),
            ),
            const SizedBox(height: 60),
          ],
        ],
      ),
    );
  }

  IconData _filterIcon(String f) {
    switch (f) {
      case 'Cardio':     return Icons.directions_run_rounded;
      case 'HIIT':       return Icons.flash_on_rounded;
      case 'Strength':   return Icons.fitness_center_rounded;
      case 'Yoga':       return Icons.self_improvement_rounded;
      case 'Stretching': return Icons.accessibility_new_rounded;
      default:           return Icons.sports_rounded;
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onMore;
  const _SectionHeader({required this.title, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.c.text)),
          ),
          GestureDetector(
            onTap: onMore,
            child: Icon(Icons.chevron_right_rounded, color: context.c.text, size: 24),
          ),
        ],
      ),
    );
  }
}

// ── Small card (What's new) ────────────────────────────────────────────────────

class _SmallCard extends StatelessWidget {
  final Map<String, String> workout;
  final VoidCallback onTap;
  const _SmallCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: context.c.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  _Thumb(videoId: workout['videoId']!, category: workout['category']!),
                  const Positioned(left: 8, bottom: 8, child: _YtPlayBtn()),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(workout['title']!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.text, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(workout['duration']!,
                    style: TextStyle(fontSize: 12, color: context.c.subtext)),
                Text(workout['channel']!,
                    style: TextStyle(fontSize: 12, color: context.c.subtext),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Large card (Featured programs) ────────────────────────────────────────────

class _LargeCard extends StatelessWidget {
  final Map<String, String> workout;
  final VoidCallback onTap;
  const _LargeCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.c.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  _Thumb(videoId: workout['videoId']!, category: workout['category']!),
                  const Positioned(left: 10, bottom: 10, child: _YtPlayBtn()),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(workout['title']!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.c.text, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${workout['duration']!}  \u2022  ${workout['channel']!}',
                    style: TextStyle(fontSize: 12, color: context.c.subtext),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── YouTube play button ────────────────────────────────────────────────────────

class _YtPlayBtn extends StatelessWidget {
  const _YtPlayBtn();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
    );
  }
}

// ── Thumbnail widget ──────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final String videoId;
  final String category;
  const _Thumb({required this.videoId, required this.category});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFE0E0E0),
        child: Center(child: Icon(_catIcon(), color: const Color(0xFFAAAAAA), size: 36)),
      ),
      placeholder: (_, __) => const ColoredBox(color: Color(0xFFE0E0E0)),
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
