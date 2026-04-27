import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/treatment_plan_provider.dart';
import '../../models/treatment_plan.dart';
import '../../utils/blob_fetch.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/media_attachment_widget.dart';
import '../../widgets/common/loading_shimmer.dart';

class TreatmentScreen extends ConsumerWidget {
  const TreatmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(treatmentPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Treatment Plans')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlanSheet(context, ref),
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.isLoading && state.plans.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingListCard(count: 3),
            )
          : state.plans.isEmpty
              ? _EmptyState(onAdd: () => _showAddPlanSheet(context, ref))
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(treatmentPlanProvider.notifier).fetchPlans(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: state.plans.length,
                    itemBuilder: (context, i) =>
                        _PlanCard(plan: state.plans[i]),
                  ),
                ),
    );
  }

  void _showAddPlanSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlanSheet(ref: ref),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_information_outlined,
                size: 64, color: kSubtext),
            const SizedBox(height: 16),
            const Text(
              'No treatment plans yet.',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: kText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first treatment plan from your doctor.',
              style: TextStyle(fontSize: 13, color: kSubtext),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Add Treatment Plan',
              onPressed: onAdd,
              leadingIcon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  final TreatmentPlan plan;
  const _PlanCard({required this.plan});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  // Created lazily on first play tap to avoid exhausting Web AudioContext limit
  AudioPlayer? _player;
  bool _isPlaying = false;

  TreatmentPlan get plan => widget.plan;

  String get _base => kServerBase;

  String _fullUrl(String path) =>
      path.startsWith('http') ? path : '$_base$path';

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final url = plan.audioUrl;
    if (url == null) return;
    _player ??= AudioPlayer(); // create lazily on first use
    if (_isPlaying) {
      await _player!.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (mounted) setState(() => _isPlaying = true);
      await _player!.play(UrlSource(_fullUrl(url)));
      _player!.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  Future<void> _openUrl(String path) async {
    final uri = Uri.parse(_fullUrl(path));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _viewPhoto(BuildContext context) {
    final url = plan.photoUrl;
    if (url == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                _fullUrl(url),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title ?? 'Treatment Plan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kText,
                        ),
                      ),
                      if (plan.conditionName != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            plan.conditionName!,
                            style: const TextStyle(
                                fontSize: 11, color: kPrimary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: plan.status),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Provider ──────────────────────────────────────────────
          if (plan.providerName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.medical_services_outlined,
                      size: 14, color: kSubtext),
                  const SizedBox(width: 6),
                  Text(plan.providerName!,
                      style: const TextStyle(fontSize: 12, color: kSubtext)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          // ── Date + cost ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (plan.planDate != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: kSubtext),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(plan.planDate!),
                    style: const TextStyle(fontSize: 12, color: kSubtext),
                  ),
                  const SizedBox(width: 12),
                ],
                if (plan.cost != null) ...[
                  const Icon(Icons.payments_outlined,
                      size: 13, color: kAccent),
                  const SizedBox(width: 4),
                  Text(
                    plan.formattedCost,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Description ───────────────────────────────────────────
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                plan.description!.length > 100
                    ? '${plan.description!.substring(0, 100)}…'
                    : plan.description!,
                style: const TextStyle(
                    fontSize: 13, color: kSubtext, height: 1.4),
              ),
            ),
          ],
          // ── Media attachments ─────────────────────────────────────
          if (plan.hasMedia) ...[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ATTACHMENTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kSubtext,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Photo
                  if (plan.photoUrl != null)
                    _MediaChip(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                      color: kPrimary,
                      onTap: () => _viewPhoto(context),
                    ),
                  // Audio
                  if (plan.audioUrl != null)
                    _MediaChip(
                      icon: _isPlaying
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      label: _isPlaying ? 'Stop' : 'Audio Note',
                      color: kPurple,
                      onTap: _toggleAudio,
                    ),
                  // Video
                  if (plan.videoUrl != null)
                    _MediaChip(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      color: kAccentAmber,
                      onTap: () => _openUrl(plan.videoUrl!),
                    ),
                  // Document
                  if (plan.documentUrl != null)
                    _MediaChip(
                      icon: Icons.attach_file,
                      label: 'Document',
                      color: kInfo,
                      onTap: () => _openUrl(plan.documentUrl!),
                    ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (kSuccess, 'Active'),
      'completed' => (kInfo, 'Completed'),
      'cancelled' => (kSubtext, 'Cancelled'),
      _ => (kSubtext, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _AddPlanSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddPlanSheet({required this.ref});

  @override
  ConsumerState<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends ConsumerState<_AddPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'UGX');
  DateTime? _planDate;
  String? _selectedCondition;
  String? _pickedFilePath;
  String? _pickedFileName;
  Uint8List? _pickedFileBytes; // used on web (no file path available)
  final _mediaController = MediaAttachmentController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _providerCtrl.dispose();
    _costCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _planDate = picked);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // required on web to get file bytes
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFilePath = kIsWeb ? null : result.files.first.path;
          _pickedFileBytes = result.files.first.bytes;
          _pickedFileName = result.files.first.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Gather photo bytes
    Uint8List? photoBytes;
    String? photoName;
    try {
      if (_mediaController.photo != null) {
        photoBytes = await _mediaController.photo!.readAsBytes();
        photoName = _mediaController.photo!.name.isNotEmpty
            ? _mediaController.photo!.name
            : 'photo.jpg';
      }
    } catch (e) {
      photoBytes = null;
    }

    // Gather audio bytes (blob URL on web, file path on native)
    Uint8List? audioBytes;
    String? audioName;
    try {
      if (_mediaController.audioPath != null) {
        if (kIsWeb) {
          audioBytes = await fetchBlobBytes(_mediaController.audioPath!);
          audioName = 'audio_note.opus';
        } else {
          audioBytes = await File(_mediaController.audioPath!).readAsBytes();
          audioName = 'audio_note.m4a';
        }
      }
    } catch (e) {
      audioBytes = null;
    }

    // Gather video bytes
    Uint8List? videoBytes;
    String? videoName;
    try {
      if (kIsWeb && _mediaController.videoPlatformFile != null) {
        videoBytes = _mediaController.videoPlatformFile!.bytes;
        videoName = _mediaController.videoName;
      } else if (!kIsWeb && _mediaController.videoFile != null) {
        videoBytes = await _mediaController.videoFile!.readAsBytes();
        videoName = _mediaController.videoName;
      }
    } catch (e) {
      videoBytes = null;
    }

    // Client-side size guard (500 MB)
    const maxBytes = 500 * 1024 * 1024;
    if (videoBytes != null && videoBytes.length > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video is too large. Please choose a file under 500 MB.'),
            backgroundColor: kError,
          ),
        );
      }
      return;
    }

    try {
      final success =
          await ref.read(treatmentPlanProvider.notifier).addPlan(
                title: _titleCtrl.text.trim().isEmpty
                    ? null
                    : _titleCtrl.text.trim(),
                description: _descCtrl.text.trim().isEmpty
                    ? null
                    : _descCtrl.text.trim(),
                providerName: _providerCtrl.text.trim().isEmpty
                    ? null
                    : _providerCtrl.text.trim(),
                conditionName: _selectedCondition,
                planDate: _planDate,
                cost: _costCtrl.text.isNotEmpty
                    ? double.tryParse(_costCtrl.text)
                    : null,
                currency: _currencyCtrl.text.trim().isNotEmpty
                    ? _currencyCtrl.text.trim()
                    : null,
                documentPath: kIsWeb ? null : _pickedFilePath,
                documentBytes: kIsWeb ? _pickedFileBytes : null,
                documentName: _pickedFileName,
                photoBytes: photoBytes,
                photoName: photoName,
                audioBytes: audioBytes,
                audioName: audioName,
                videoBytes: videoBytes,
                videoName: videoName,
              );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treatment plan added successfully!'),
            backgroundColor: kSuccess,
          ),
        );
        Navigator.pop(context);
      } else {
        final err = ref.read(treatmentPlanProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to save treatment plan'),
            backgroundColor: kError,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treatmentPlanProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add Treatment Plan',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kText),
              ),
              const SizedBox(height: 20),
              AppInput(
                label: 'Title (optional)',
                hint: 'e.g. Diabetes Management Plan',
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              AppInput(
                label: 'Description',
                hint: 'Describe your treatment plan...',
                controller: _descCtrl,
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe your treatment plan'
                    : null,
              ),
              const SizedBox(height: 14),
              AppInput(
                label: 'Doctor / Provider Name (optional)',
                hint: 'e.g. Dr. Nakamura',
                controller: _providerCtrl,
                prefixIcon: const Icon(Icons.medical_services_outlined,
                    color: kSubtext),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              // Plan date picker
              const Text(
                'Plan Date (optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kText),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: kSubtext, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _planDate != null
                            ? DateFormat('dd MMM yyyy')
                                .format(_planDate!)
                            : 'Select date',
                        style: TextStyle(
                          color:
                              _planDate != null ? kText : kSubtext,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppInput(
                      label: 'Cost (optional)',
                      hint: 'e.g. 150000',
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      label: 'Currency',
                      hint: 'UGX',
                      controller: _currencyCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Document upload
              const Text(
                'Prescription (Optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kText),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kPrimary.withValues(alpha: 0.2),
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: kPrimary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedFileName ??
                              'Attach Treatment Document (optional)',
                          style: TextStyle(
                            color: _pickedFileName != null
                                ? kText
                                : kSubtext,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_pickedFileName != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _pickedFilePath = null;
                            _pickedFileName = null;
                            _pickedFileBytes = null;
                          }),
                          child: const Icon(Icons.close,
                              size: 16, color: kSubtext),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Doctor Visit Media (photo, audio note, video)
              MediaAttachmentWidget(
                controller: _mediaController,
                label: 'Doctor Visit Media (optional)',
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Add Treatment Plan',
                onPressed: _submit,
                isLoading: state.isLoading,
                leadingIcon: Icons.add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
