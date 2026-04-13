import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/medication.dart';
import '../../providers/medications_provider.dart';
import '../../widgets/common/loading_shimmer.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicationsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(routeAddMedication),
          icon: const Icon(Icons.add),
          label: const Text('Add Medication'),
        ),
        body: TabBarView(
          children: [
            _CurrentMedsTab(state: state, ref: ref),
            _MedsHistoryTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _CurrentMedsTab extends StatelessWidget {
  final MedicationsState state;
  final WidgetRef ref;

  const _CurrentMedsTab({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => const LoadingMedicationCard()),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: kError, size: 48),
            const SizedBox(height: 12),
            Text(state.error!,
                style: const TextStyle(color: kSubtext), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(medicationsProvider.notifier).fetchMedications(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.currentMeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication_outlined,
                color: Color(0xFFCBD5E1), size: 64),
            const SizedBox(height: 16),
            const Text(
              'No medications added yet',
              style: TextStyle(
                  color: kSubtext, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to add your first medication.',
              style: TextStyle(color: kSubtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () =>
          ref.read(medicationsProvider.notifier).fetchMedications(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.currentMeds.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _AdherenceCard(state: state);
          final med = state.currentMeds[i - 1];
          return _MedicationCard(med: med, ref: ref);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADHERENCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AdherenceCard extends StatelessWidget {
  final MedicationsState state;

  const _AdherenceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final meds = state.currentMeds;
    if (meds.isEmpty) return const SizedBox();

    final overallAdherence = meds.map((m) => m.adherencePercent).reduce((a, b) => a + b) / meds.length;
    final taken = meds.where((m) => m.isTakenToday).length;
    final missed = meds.where((m) => m.isSkippedToday).length;
    final total = meds.length;

    // Approximate streak from adherencePercent
    final streak = (overallAdherence / 100 * 7).round().clamp(0, 7);
    final bestStreak = (overallAdherence / 100 * 30).round().clamp(0, 30);

    final Color adColor = overallAdherence >= 80
        ? kSuccess
        : overallAdherence >= 50
            ? kWarning
            : kError;
    final double progress = (overallAdherence / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              const Icon(Icons.medication_rounded, color: kPrimary, size: 20),
              const SizedBox(width: 8),
              const Text("💊 This Week's Adherence",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kText)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: adColor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(adColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${overallAdherence.toInt()}%',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: adColor,
                                height: 1)),
                        Text('adherence',
                            style: TextStyle(
                                fontSize: 9,
                                color: adColor.withValues(alpha: 0.8))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statChip('$total doses', kSubtext),
                        const SizedBox(width: 6),
                        _statChip('$taken taken', kSuccess),
                        const SizedBox(width: 6),
                        _statChip('$missed missed', kError),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text('Current streak: $streak days',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kText)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text('Best streak: $bestStreak days',
                            style: const TextStyle(
                                fontSize: 12, color: kSubtext)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _MedicationCard extends StatefulWidget {
  final dynamic med;
  final WidgetRef ref;

  const _MedicationCard({required this.med, required this.ref});

  @override
  State<_MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<_MedicationCard> {
  Future<void> _confirmStop() async {
    final med = widget.med;
    final ref = widget.ref;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stop Taking Medication?'),
        content: Text(
          'Mark "${med.name.isNotEmpty ? med.name : 'this medication'}" as completed?\n\n'
          'It will move to your medication history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kError),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop Taking'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await ref.read(medicationsProvider.notifier).stopMedication(med.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    final ref = widget.ref;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/medications/${med.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.medication, color: kPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kText,
                          ),
                        ),
                        Text(
                          '${med.dosage} · ${med.frequency}',
                          style: const TextStyle(
                              fontSize: 12, color: kSubtext),
                        ),
                      ],
                    ),
                  ),
                  if (med.isTakenToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: kSuccess, size: 12),
                          SizedBox(width: 3),
                          Text(
                            'Taken',
                            style: TextStyle(
                                color: kSuccess,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else if (med.isSkippedToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSubtext.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Skipped',
                        style: TextStyle(
                            color: kSubtext,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: kSubtext, size: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'stop') _confirmStop();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'stop',
                        child: Row(
                          children: [
                            Icon(Icons.stop_circle_outlined,
                                color: kError, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Stop Taking',
                              style: TextStyle(
                                  color: kError,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pharmacy & refill info
              if (med.pharmacyName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.local_pharmacy_outlined,
                        size: 13, color: kSubtext),
                    const SizedBox(width: 4),
                    Text(
                      med.pharmacyName!,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (med.nextRefillDate != null) ...[
                _RefillChip(nextRefillDate: med.nextRefillDate!),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '7-day adherence',
                              style: TextStyle(
                                  fontSize: 11, color: kSubtext),
                            ),
                            const Spacer(),
                            Text(
                              '${med.adherencePercent.toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: med.adherencePercent >= 80
                                    ? kSuccess
                                    : med.adherencePercent >= 50
                                        ? kWarning
                                        : kError,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: med.adherencePercent / 100,
                            backgroundColor: kBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              med.adherencePercent >= 80
                                  ? kSuccess
                                  : med.adherencePercent >= 50
                                      ? kWarning
                                      : kError,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!med.isTakenToday && !med.isSkippedToday) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(medicationsProvider.notifier)
                            .logDose(med.id, 'skipped'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Skip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSubtext,
                          side: const BorderSide(color: kBorder),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                            .read(medicationsProvider.notifier)
                            .logDose(med.id, 'taken'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Mark Taken'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccess,
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 20, color: kBorder),
              TextButton.icon(
                onPressed: _confirmStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 15, color: kError),
                label: const Text(
                  'Stop Taking This Medication',
                  style: TextStyle(
                    color: kError,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (med.photoUrl != null ||
                  med.audioUrl != null ||
                  med.videoUrl != null ||
                  med.prescriptionUrl != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: kBorder),
                const SizedBox(height: 10),
                _CardMediaStrip(med: med),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Media strip shown at the bottom of each medication card
// ─────────────────────────────────────────────────────────────
class _CardMediaStrip extends StatefulWidget {
  final dynamic med;
  const _CardMediaStrip({required this.med});

  @override
  State<_CardMediaStrip> createState() => _CardMediaStripState();
}

class _CardMediaStripState extends State<_CardMediaStrip> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String relPath) async {
    final url = '$kServerBase$relPath';
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(url));
      setState(() => _isPlaying = true);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  Future<void> _openUrl(String relPath) async {
    final uri = Uri.parse('$kServerBase$relPath');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showPhoto(BuildContext context, String relPath) {
    final url = relPath.startsWith('http')
        ? relPath
        : '$kServerBase$relPath';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (med.photoUrl != null)
          _MediaChip(
            icon: Icons.image_outlined,
            label: 'Photo',
            color: Colors.blue,
            onTap: () => _showPhoto(context, med.photoUrl as String),
          ),
        if (med.audioUrl != null)
          _MediaChip(
            icon: _isPlaying
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            label: _isPlaying ? 'Pause' : 'Audio',
            color: Colors.orange,
            onTap: () => _toggleAudio(med.audioUrl as String),
          ),
        if (med.videoUrl != null)
          _MediaChip(
            icon: Icons.videocam_outlined,
            label: 'Video',
            color: const Color(0xFF32ADE6),
            onTap: () => _openUrl(med.videoUrl as String),
          ),
        if (med.prescriptionUrl != null)
          _MediaChip(
            icon: Icons.description_outlined,
            label: 'Prescription',
            color: Colors.teal,
            onTap: () => _openUrl(med.prescriptionUrl as String),
          ),
      ],
    );
  }
}

class _MediaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedsHistoryTab extends StatelessWidget {
  final MedicationsState state;

  const _MedsHistoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3, (_) => const LoadingMedicationCard()),
      );
    }

    final history = state.historyMeds;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, color: Color(0xFFCBD5E1), size: 64),
              const SizedBox(height: 16),
              const Text(
                'No completed medications',
                style: TextStyle(
                    color: kSubtext,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Medications with a past end date will appear here.',
                style: TextStyle(color: kSubtext, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final med = history[i];
        return _HistoryMedCard(med: med);
      },
    );
  }
}

class _HistoryMedCard extends StatelessWidget {
  final Medication med;
  const _HistoryMedCard({required this.med});

  @override
  Widget build(BuildContext context) {
    String? rangeLabel;
    try {
      if (med.startDate != null && med.endDate != null) {
        final start = DateTime.parse(med.startDate!);
        final end = DateTime.parse(med.endDate!);
        final days = end.difference(start).inDays;
        rangeLabel =
            '${start.day}/${start.month}/${start.year} – ${end.day}/${end.month}/${end.year}  ($days days)';
      } else if (med.startDate != null) {
        final start = DateTime.parse(med.startDate!);
        rangeLabel = 'Started ${start.day}/${start.month}/${start.year}';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/medications/${med.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kSubtext.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication, color: kSubtext, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name.isNotEmpty ? med.name : 'Medication (see media)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: kText,
                      ),
                    ),
                    if (med.dosage.isNotEmpty || med.frequency.isNotEmpty)
                      Text(
                        [
                          if (med.dosage.isNotEmpty) med.dosage,
                          if (med.frequency.isNotEmpty) med.frequency,
                        ].join(' · '),
                        style:
                            const TextStyle(fontSize: 12, color: kSubtext),
                      ),
                    if (rangeLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        rangeLabel,
                        style: const TextStyle(
                            fontSize: 11, color: kSubtext),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 12, color: kSuccess),
                        const SizedBox(width: 4),
                        Text(
                          '${med.adherencePercent.toInt()}% adherence',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kSuccess,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (med.condition != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        med.condition!,
                        style: const TextStyle(
                            fontSize: 11, color: kSubtext),
                      ),
                    ],
                    if (med.pharmacyName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_pharmacy_outlined,
                              size: 11, color: kSubtext),
                          const SizedBox(width: 3),
                          Text(
                            med.pharmacyName!,
                            style: const TextStyle(
                                fontSize: 11, color: kSubtext),
                          ),
                        ],
                      ),
                    ],
                    if (med.nextRefillDate != null) ...[
                      const SizedBox(height: 4),
                      _RefillChip(nextRefillDate: med.nextRefillDate!),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kSubtext.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                      color: kSubtext,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Refill Countdown Chip ─────────────────────────────────────────────────────
class _RefillChip extends StatelessWidget {
  final String nextRefillDate;
  const _RefillChip({required this.nextRefillDate});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(nextRefillDate);
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final days = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final overdue = days < 0;
    final soon = days <= 7;

    final Color chipColor = overdue
        ? kError
        : soon
            ? kWarning
            : kSuccess;
    final String label = overdue
        ? 'Refill overdue by ${(-days)} days'
        : days == 0
            ? 'Refill due today'
            : 'Next refill: ${DateFormat('d MMM').format(date)} ($days days)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 11, color: chipColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: chipColor,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
