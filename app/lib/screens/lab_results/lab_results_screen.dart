import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/lab_tests_provider.dart';
import '../../providers/member_provider.dart';
import '../../models/lab_test.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/loading_shimmer.dart';

/// Resolves a relative result path like /uploads/lab-results/x.pdf
/// to a fully-qualified URL using the API server's host.
String _resolveResultUrl(String rawUrl) {
  if (rawUrl.startsWith('http')) return rawUrl;
  // kBaseUrl e.g. 'https://app.sanlamallianz4u.co.ug/api' → strip '/api'
  final host = kBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  return '$host$rawUrl';
}

Future<void> _openResultFile(BuildContext context, String rawUrl) async {
  final url = Uri.parse(_resolveResultUrl(rawUrl));
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the result file.'),
        backgroundColor: kError,
      ),
    );
  }
}

class LabResultsScreen extends ConsumerWidget {
  const LabResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labTestsProvider);
    final conditions = ref.watch(memberProvider).member?.conditions ?? [];

    // ── Condition-aware banner text ──────────────────────────────────────────
    final hasDiabetes = conditions.any((c) => c.toLowerCase().contains('diabetes'));
    final hasHypertension = conditions.any((c) =>
        c.toLowerCase().contains('hypertension') ||
        c.toLowerCase().contains('high blood pressure'));
    final bannerText = hasDiabetes
        ? 'As a diabetic, annual kidney function and liver function tests are critical. Early detection prevents complications.'
        : hasHypertension
            ? 'Hypertension can damage kidneys over time. Regular KFT tests help detect this early.'
            : 'Regular lab tests help monitor your organ health. Complete your tests on time.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Results'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Liver & Kidney Function Tests',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kInfo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kInfo.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: kInfo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bannerText,
                    style: const TextStyle(
                        fontSize: 12, color: kText, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.tests.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingListCard(count: 3),
                  )
                : state.tests.isEmpty
                    ? const _EmptyLabState()
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(labTestsProvider.notifier).fetchTests(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: state.tests.length,
                          itemBuilder: (context, i) => _LabTestCard(
                            test: state.tests[i],
                            conditions: conditions,
                            onMarkDone: () => _showMarkDoneSheet(
                                context, ref, state.tests[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showMarkDoneSheet(BuildContext context, WidgetRef ref, LabTest test) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkDoneSheet(test: test, ref: ref),
    );
  }
}

class _EmptyLabState extends StatelessWidget {
  const _EmptyLabState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 64, color: kSubtext),
            SizedBox(height: 16),
            Text(
              'No lab tests scheduled yet.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kText),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Your care team will schedule tests for you.',
              style: TextStyle(fontSize: 13, color: kSubtext),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabTestCard extends StatefulWidget {
  final LabTest test;
  final List<String> conditions;
  final VoidCallback onMarkDone;

  const _LabTestCard({required this.test, required this.conditions, required this.onMarkDone});

  @override
  State<_LabTestCard> createState() => _LabTestCardState();
}

class _LabTestCardState extends State<_LabTestCard> {
  bool _showGuide = false;

  List<String> _getInterpretationLines() {
    final test = widget.test;
    final conds = widget.conditions;
    final hasDiabetes = conds.any((c) => c.toLowerCase().contains('diabetes'));
    final hasHypertension = conds.any((c) =>
        c.toLowerCase().contains('hypertension') ||
        c.toLowerCase().contains('high blood pressure'));
    final hasHeart = conds.any((c) =>
        c.toLowerCase().contains('heart') ||
        c.toLowerCase().contains('coronary') ||
        c.toLowerCase().contains('cardiac'));
    final hasCKD = conds.any((c) =>
        c.toLowerCase().contains('kidney') ||
        c.toLowerCase().contains('renal') ||
        c.toLowerCase().contains('ckd'));

    final lines = <String>[];

    if (test.testType == 'liver_function') {
      lines.add('📋 LFT measures ALT, AST, bilirubin, and albumin. Elevated ALT/AST indicates liver inflammation.');
      if (hasDiabetes) {
        lines.add('🩸 Diabetics are at higher risk of fatty liver disease (NAFLD). If your doctor finds elevated ALT/AST, discuss lifestyle changes to protect your liver.');
      }
      if (hasHeart) {
        lines.add('❤️ Some cardiac medications can affect liver enzymes. Report any significant changes to your cardiologist.');
      }
    } else if (test.testType == 'kidney_function') {
      lines.add('📋 KFT measures creatinine, urea, and eGFR. An eGFR <60 indicates reduced kidney function.');
      if (hasDiabetes) {
        lines.add('🩸 Diabetes is the leading cause of kidney disease. Target HbA1c <7% and BP <130/80 to slow kidney damage.');
      }
      if (hasHypertension) {
        lines.add('🩺 High BP damages kidney filtration units. Consistent BP control is the most important factor in protecting your kidneys.');
      }
      if (hasCKD) {
        lines.add('🫘 Regular KFT monitoring is essential. Discuss your eGFR trend and target with your nephrologist.');
      }
    }

    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final statusColor = test.isCompleted
        ? kSuccess
        : test.isOverdue
            ? kError
            : kWarning;
    final statusLabel = test.isCompleted
        ? 'COMPLETED'
        : test.isOverdue
            ? 'OVERDUE'
            : 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.science_outlined, color: kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.testTypeLabel,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kText),
                    ),
                    Text(
                      test.testTypeShort,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: kSubtext),
              const SizedBox(width: 4),
              Text(
                'Due: ${test.formattedDueDate}',
                style: const TextStyle(fontSize: 12, color: kSubtext),
              ),
            ],
          ),
          if (test.isCompleted && test.completedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 13, color: kSuccess),
                const SizedBox(width: 4),
                Text(
                  'Completed: ${DateFormat('dd MMM yyyy').format(test.completedAt!)}',
                  style: const TextStyle(fontSize: 12, color: kSuccess),
                ),
              ],
            ),
          ],
          if (test.isCompleted && test.resultNotes != null && test.resultNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                test.resultNotes!,
                style: const TextStyle(fontSize: 12, color: kSubtext),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (test.isCompleted) ...[
            if (test.resultFileUrl != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _openResultFile(context, test.resultFileUrl!),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('View Result',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    backgroundColor: kPrimary.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            // ── Interpretation Guide ────────────────────────────────────────
            const SizedBox(height: 10),
            _buildInterpretationGuide(),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onMarkDone,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark as Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccess,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterpretationGuide() {
    final lines = _getInterpretationLines();
    if (lines.isEmpty) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _showGuide = !_showGuide),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kInfo.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kInfo.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: kInfo, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Interpretation Guide',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kInfo)),
                ),
                Icon(
                  _showGuide
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: kInfo,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_showGuide) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kInfo.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kInfo.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(line,
                            style: const TextStyle(
                                fontSize: 12,
                                color: kSubtext,
                                height: 1.4)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MarkDoneSheet extends ConsumerStatefulWidget {
  final LabTest test;
  final WidgetRef ref;

  const _MarkDoneSheet({required this.test, required this.ref});

  @override
  ConsumerState<_MarkDoneSheet> createState() => _MarkDoneSheetState();
}

class _MarkDoneSheetState extends ConsumerState<_MarkDoneSheet> {
  final _notesCtrl = TextEditingController();
  String? _pickedFileName;
  String?    _pickedFilePath;   // native
  Uint8List? _pickedFileBytes;  // web

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      if (kIsWeb) {
        // On web skip the dialog — opening it loses the user-gesture context
        // and the browser blocks the file input.
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty && mounted) {
          setState(() {
            _pickedFileBytes = result.files.first.bytes;
            _pickedFileName  = result.files.first.name;
            _pickedFilePath  = null;
          });
        }
      } else {
        final source = await _showSourceDialog();
        if (source == null) return;
        final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
        if (file != null && mounted) {
          setState(() {
            _pickedFilePath  = file.path;
            _pickedFileName  = file.name;
            _pickedFileBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e'), backgroundColor: kError),
        );
      }
    }
  }

  Future<ImageSource?> _showSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upload Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final success = await ref.read(labTestsProvider.notifier).completeTest(
          widget.test.id,
          resultNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          filePath:  kIsWeb ? null : _pickedFilePath,
          fileBytes: kIsWeb ? _pickedFileBytes : null,
          fileName:  _pickedFileName,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab test marked as completed!'),
          backgroundColor: kSuccess,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final err = ref.read(labTestsProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: kError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labTestsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(
            'Mark as Done — ${widget.test.testTypeShort}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: kText),
          ),
          const SizedBox(height: 20),
          AppInput(
            label: 'Result Notes (optional)',
            hint: 'Any notes about your results...',
            controller: _notesCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_outlined,
                      color: kPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'Upload Result (photo/PDF)',
                      style: TextStyle(
                        color: _pickedFileName != null ? kText : kSubtext,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Submit',
            onPressed: _submit,
            isLoading: state.isLoading,
            leadingIcon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}
