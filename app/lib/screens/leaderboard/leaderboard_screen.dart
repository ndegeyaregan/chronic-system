import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/leaderboard_entry.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/auth_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'weekly';

  static const _bg     = Color(0xFFF2F4F8);
  static const _card   = Colors.white;
  static const _gold   = Color(0xFFFFCC00);
  static const _silver = Color(0xFFB0BEC5);
  static const _bronze = Color(0xFFCD7F32);

  Color _rankColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return kSubtext;
  }

  String _rankEmoji(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    final leaderState = ref.watch(leaderboardProvider);
    final member = ref.watch(authProvider).member;
    final entries = leaderState.entries;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Wellness Leaderboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () =>
                ref.read(leaderboardProvider.notifier).fetch(period: _period),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _PeriodTabs(
            selected: _period,
            onChanged: (p) {
              setState(() => _period = p);
              ref.read(leaderboardProvider.notifier).fetch(period: p);
            },
          ),
        ),
      ),
      body: leaderState.isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: () => ref
                  .read(leaderboardProvider.notifier)
                  .fetch(period: _period),
              child: CustomScrollView(
                slivers: [
                  // ── Info banner ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _PointsBanner(),
                  ),

                  // ── Error / offline ─────────────────────────────────────
                  if (leaderState.error != null && entries.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  size: 56, color: kSubtext),
                              const SizedBox(height: 16),
                              Text(
                                leaderState.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: kSubtext, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // ── Podium (top 3) ──────────────────────────────────
                    if (entries.length >= 3)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: _Podium(
                            entries: entries.take(3).toList(),
                            currentMemberId: member?.id ?? '',
                          ),
                        ),
                      ),

                    // ── Divider ─────────────────────────────────────────
                    if (entries.length > 3)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('All Rankings',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: kSubtext,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const Expanded(child: Divider()),
                          ]),
                        ),
                      ),

                    // ── Full list ───────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final entry =
                                entries.length >= 3 ? entries[i + 3] : entries[i];
                            final isMe = entry.memberId == (member?.id ?? '');
                            return _LeaderRow(
                              entry: entry,
                              isCurrentUser: isMe,
                              rankColor: _rankColor(entry.rank),
                              rankLabel: _rankEmoji(entry.rank),
                            );
                          },
                          childCount: entries.length >= 3
                              ? entries.length - 3
                              : entries.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Period Tab Bar ─────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const periods = [
      ('weekly', 'This Week'),
      ('monthly', 'This Month'),
      ('alltime', 'All Time'),
    ];
    return Container(
      color: kPrimaryDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: periods.map((p) {
          final isActive = p.$1 == selected;
          return GestureDetector(
            onTap: () => onChanged(p.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
              child: Text(
                p.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? kPrimaryDark : Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Points info banner ─────────────────────────────────────────────────────

class _PointsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How points are earned',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _PointPill(icon: Icons.directions_run_rounded,
                  label: 'Fitness logs', color: Color(0xFF34C759)),
              _PointPill(icon: Icons.play_circle_fill_rounded,
                  label: 'Workout videos', color: Color(0xFF007AFF)),
              _PointPill(icon: Icons.monitor_heart_outlined,
                  label: 'Vitals logged', color: Color(0xFFFF3B30)),
              _PointPill(icon: Icons.medication_outlined,
                  label: 'Medications', color: Color(0xFFFF9500)),
              _PointPill(icon: Icons.restaurant_menu_outlined,
                  label: 'Meals logged', color: Color(0xFF32ADE6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PointPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Podium widget ──────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String currentMemberId;
  const _Podium({required this.entries, required this.currentMemberId});

  @override
  Widget build(BuildContext context) {
    // Podium order: 2nd (left), 1st (center, tallest), 3rd (right)
    final order = [entries[1], entries[0], entries[2]];
    final heights = [90.0, 120.0, 75.0];
    final colors = [
      const Color(0xFFB0BEC5),
      const Color(0xFFFFCC00),
      const Color(0xFFCD7F32),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final e = order[i];
        final isMe = e.memberId == currentMemberId;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i].withValues(alpha: 0.2),
                  border: Border.all(
                    color: isMe ? kPrimary : colors[i],
                    width: isMe ? 2.5 : 2,
                  ),
                ),
                child: Center(
                  child: Text(e.initials,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: isMe ? kPrimary : colors[i])),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.memberName.split(' ').first,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kText),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${e.totalPoints} pts',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors[i]),
              ),
              const SizedBox(height: 6),
              // Platform block
              Container(
                height: heights[i],
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors[i].withValues(alpha: 0.8),
                      colors[i],
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                ),
                child: Center(
                  child: Text(
                    i == 1 ? '🥇' : (i == 0 ? '🥈' : '🥉'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Leaderboard row ────────────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final Color rankColor;
  final String rankLabel;
  const _LeaderRow({
    required this.entry,
    required this.isCurrentUser,
    required this.rankColor,
    required this.rankLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? kPrimary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: isCurrentUser
            ? Border.all(color: kPrimary.withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              rankLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: entry.rank <= 3 ? 20 : 14,
                fontWeight: FontWeight.w700,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser
                  ? kPrimary.withValues(alpha: 0.15)
                  : kSubtext.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                entry.initials,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isCurrentUser ? kPrimary : kSubtext),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name & breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCurrentUser
                            ? '${entry.memberName} (You)'
                            : entry.memberName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isCurrentUser ? kPrimary : kText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.rankChange != 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.rankChange > 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: entry.rankChange > 0
                                ? kAccent
                                : kError,
                          ),
                          Text(
                            '${entry.rankChange.abs()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: entry.rankChange > 0 ? kAccent : kError,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Mini point breakdown
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MiniStat(Icons.directions_run_rounded,
                          entry.fitnessPoints, const Color(0xFF34C759)),
                      _MiniStat(Icons.play_circle_fill_rounded,
                          entry.workoutPoints, const Color(0xFF007AFF)),
                      _MiniStat(Icons.monitor_heart_outlined,
                          entry.vitalPoints, const Color(0xFFFF3B30)),
                      _MiniStat(Icons.medication_outlined,
                          entry.medicationPoints, const Color(0xFFFF9500)),
                      _MiniStat(Icons.restaurant_menu_outlined,
                          entry.mealPoints, const Color(0xFF32ADE6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalPoints}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kText),
              ),
              const Text(
                'pts',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: kSubtext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  const _MiniStat(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
