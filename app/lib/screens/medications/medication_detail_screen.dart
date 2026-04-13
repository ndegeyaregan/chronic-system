import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/medications_provider.dart';

class MedicationDetailScreen extends ConsumerWidget {
  final String id;

  const MedicationDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicationsProvider);
    final med = state.medications.where((m) => m.id == id).firstOrNull;

    if (med == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medication')),
        body: const Center(child: Text('Medication not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(med.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove Medication'),
                  content: Text(
                      'Remove ${med.name} from your medications?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kError),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(medicationsProvider.notifier)
                    .deleteMedication(id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimary.withValues(alpha: 0.08),
                    kPrimary.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication,
                        color: kPrimary, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kText,
                          ),
                        ),
                        Text(
                          med.dosage,
                          style: const TextStyle(
                              fontSize: 14, color: kSubtext),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.schedule_outlined, 'Frequency', med.frequency),
            if (med.condition != null)
              _detailRow(Icons.local_hospital_outlined, 'Condition',
                  med.condition!),
            if (med.instructions != null)
              _detailRow(
                  Icons.info_outline, 'Instructions', med.instructions!),
            if (med.nextDoseTime != null)
              _detailRow(Icons.alarm_outlined, 'Next Dose', med.nextDoseTime!),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7-Day Adherence',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: kText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${med.adherencePercent.toInt()}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: med.adherencePercent >= 80
                              ? kSuccess
                              : med.adherencePercent >= 50
                                  ? kWarning
                                  : kError,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
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
                            minHeight: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!med.isTakenToday && !med.isSkippedToday) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(medicationsProvider.notifier)
                          .logDose(med.id, 'skipped'),
                      icon: const Icon(Icons.close),
                      label: const Text('Skip Today'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => ref
                          .read(medicationsProvider.notifier)
                          .logDose(med.id, 'taken'),
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Taken'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccess),
                    ),
                  ),
                ],
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: kSuccess),
                    const SizedBox(width: 8),
                    Text(
                      med.isTakenToday
                          ? 'Medication taken today ✓'
                          : 'Dose skipped today',
                      style: TextStyle(
                        color: med.isTakenToday ? kSuccess : kSubtext,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            // ── Media Attachments ───────────────────────────────────────────
            if (med.photoUrl != null || med.audioUrl != null ||
                med.videoUrl != null || med.prescriptionUrl != null) ...[
              const SizedBox(height: 20),
              _MedicationMediaSection(med: med),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimary, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: kSubtext)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: kText)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Media section widget ───────────────────────────────────────────────────────

class _MedicationMediaSection extends StatefulWidget {
  final dynamic med;
  const _MedicationMediaSection({required this.med});

  @override
  State<_MedicationMediaSection> createState() =>
      _MedicationMediaSectionState();
}

class _MedicationMediaSectionState extends State<_MedicationMediaSection> {
  AudioPlayer? _player;
  bool _isPlaying = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String url) async {
    _player ??= AudioPlayer();
    if (_isPlaying) {
      await _player!.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      final fullUrl = '$kServerBase$url';
      await _player!.play(UrlSource(fullUrl));
      _player!.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.perm_media_outlined, color: kPrimary, size: 16),
              SizedBox(width: 6),
              Text(
                'Doctor Visit Media',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: kText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (med.photoUrl != null)
            _MediaTile(
              icon: Icons.image_outlined,
              label: 'Visit Photo',
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: kPrimary, size: 20),
                onPressed: () {
                  final url = '$kServerBase${med.photoUrl}';
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
                              icon: const Icon(Icons.close,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (med.audioUrl != null)
            _MediaTile(
              icon: Icons.audiotrack,
              label: 'Audio Note',
              trailing: IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: kPrimary,
                  size: 26,
                ),
                onPressed: () => _toggleAudio(med.audioUrl!),
              ),
            ),
          if (med.videoUrl != null)
            _MediaTile(
              icon: Icons.video_file_outlined,
              label: 'Visit Video',
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: kPrimary, size: 20),
                onPressed: () async {
                  final url =
                      Uri.parse('$kServerBase${med.videoUrl}');
                  await launchUrl(url,
                      mode: LaunchMode.externalApplication);
                },
              ),
            ),
          if (med.prescriptionUrl != null)
            _MediaTile(
              icon: Icons.description_outlined,
              label: 'Prescription',
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: kPrimary, size: 20),
                onPressed: () async {
                  final url = Uri.parse(
                      '$kServerBase${med.prescriptionUrl}');
                  await launchUrl(url,
                      mode: LaunchMode.externalApplication);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _MediaTile({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: kText)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
