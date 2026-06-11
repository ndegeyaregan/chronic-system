import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/dependant.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependants_provider.dart';
import '../../services/api_service.dart';
import 'card_reprint_history_screen.dart';

/// Opens the card-reprint flow as a modal bottom sheet.
Future<void> showReprintCardSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReprintCardSheet(),
  );
}

class _ReprintCardSheet extends ConsumerStatefulWidget {
  const _ReprintCardSheet();

  @override
  ConsumerState<_ReprintCardSheet> createState() => _ReprintCardSheetState();
}

class _ReprintCardSheetState extends ConsumerState<_ReprintCardSheet> {
  int _step = 0;
  String? _reason; // 'lost' | 'damaged' | 'stolen' | 'other'
  final _reasonNotesCtrl = TextEditingController();
  final _txIdCtrl = TextEditingController();
  bool _isForDependant = false;
  Dependant? _selectedDependant;
  PlatformFile? _proofFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reasonNotesCtrl.addListener(_refresh);
    _txIdCtrl.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reasonNotesCtrl.removeListener(_refresh);
    _reasonNotesCtrl.dispose();
    _txIdCtrl.removeListener(_refresh);
    _txIdCtrl.dispose();
    super.dispose();
  }

  bool get _step0Valid {
    if (_reason == null) return false;
    if (_reason == 'other' && _reasonNotesCtrl.text.trim().isEmpty) return false;
    return true;
  }

  bool get _step1Valid {
    if (_isForDependant) return _selectedDependant != null;
    return true;
  }

  bool get _step2Valid {
    // Member must provide a screenshot OR a transaction id as proof.
    return _proofFile != null || _txIdCtrl.text.trim().isNotEmpty;
  }

  void _next() {
    if (_step == 0 && !_step0Valid) return;
    if (_step == 1 && !_step1Valid) return;
    if (_step == 2 && !_step2Valid) return;
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, 3));

  Future<void> _pickProofFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is too large. Maximum size is 10 MB.'),
            backgroundColor: kError,
          ),
        );
        return;
      }
      setState(() => _proofFile = f);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick file: $e'),
          backgroundColor: kError,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final member = ref.read(authProvider).member;
    if (member == null) return;
    if (!_step2Valid) return;
    setState(() => _submitting = true);
    try {
      final targetMemberNo =
          _isForDependant ? _selectedDependant!.memberNo : member.memberNumber;
      final targetMemberName = _isForDependant
          ? _selectedDependant!.name
          : '${member.firstName} ${member.lastName}'.trim();
      final targetRelation = _isForDependant
          ? (_selectedDependant!.relation.isNotEmpty
              ? _selectedDependant!.relation
              : 'Dependant')
          : 'Principal';

      final fields = <String, dynamic>{
        'targetMemberNo': targetMemberNo,
        'targetMemberName': targetMemberName,
        'targetRelation': targetRelation,
        'isForDependant': _isForDependant.toString(),
        'reason': _reason,
        'reasonNotes': _reasonNotesCtrl.text.trim(),
        'paymentMethod': 'ussd_mobile_money',
        if (_txIdCtrl.text.trim().isNotEmpty)
          'paymentReference': _txIdCtrl.text.trim(),
      };

      Response res;
      if (_proofFile != null) {
        MultipartFile mpf;
        if (_proofFile!.bytes != null) {
          mpf = MultipartFile.fromBytes(
            _proofFile!.bytes!,
            filename: _proofFile!.name,
          );
        } else {
          mpf = await MultipartFile.fromFile(
            _proofFile!.path!,
            filename: _proofFile!.name,
          );
        }
        final formData =
            FormData.fromMap({...fields, 'paymentProof': mpf});
        res = await dio.post(
          '/card-reprints',
          data: formData,
        );
      } else {
        res = await dio.post('/card-reprints', data: fields);
      }
      if (!mounted) return;
      ref.invalidate(cardReprintHistoryProvider);

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _step = 3);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit request. Please try again.'),
            backgroundColor: kError,
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(extractErrorMessage(e)),
          backgroundColor: kError,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: kError),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _Header(step: _step),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: switch (_step) {
                      0 => _StepReason(
                          reason: _reason,
                          notesCtrl: _reasonNotesCtrl,
                          onChanged: (v) => setState(() => _reason = v),
                        ),
                      1 => _StepWho(
                          isForDependant: _isForDependant,
                          selected: _selectedDependant,
                          onScopeChanged: (v) {
                            setState(() {
                              _isForDependant = v;
                              if (!v) _selectedDependant = null;
                            });
                          },
                          onDependantSelected: (d) =>
                              setState(() => _selectedDependant = d),
                        ),
                      2 => _StepPayment(
                          memberNumber: _isForDependant
                              ? (_selectedDependant?.memberNo ?? '')
                              : (ref.read(authProvider).member?.memberNumber ?? ''),
                          txIdCtrl: _txIdCtrl,
                          proofFile: _proofFile,
                          onPickProof: _pickProofFile,
                          onClearProof: () =>
                              setState(() => _proofFile = null),
                        ),
                      _ => _StepSuccess(
                          isForDependant: _isForDependant,
                          selectedDependant: _selectedDependant,
                          principal: ref.read(authProvider).member,
                        ),
                    },
                  ),
                ),
                _Footer(
                  step: _step,
                  canNext: switch (_step) {
                    0 => _step0Valid,
                    1 => _step1Valid,
                    2 => _step2Valid,
                    _ => true,
                  },
                  submitting: _submitting,
                  onBack: _step == 0 || _step == 3 ? null : _back,
                  onNext: _step == 2 ? _submit : _next,
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  const _Header({required this.step});

  @override
  Widget build(BuildContext context) {
    final titles = const [
      'Reason for Reprint',
      'Who is the card for?',
      'Payment Instructions',
      'Request Submitted',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_outlined, color: kPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titles[step],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                step < 3 ? 'Step ${step + 1} of 3' : '',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (step < 3)
            Row(
              children: List.generate(3, (i) {
                final active = i <= step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: active ? kPrimary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _StepReason extends StatelessWidget {
  final String? reason;
  final TextEditingController notesCtrl;
  final ValueChanged<String> onChanged;
  const _StepReason({
    required this.reason,
    required this.notesCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final reasons = const [
      ('lost', 'Lost', Icons.search_off),
      ('damaged', 'Damaged', Icons.broken_image_outlined),
      ('stolen', 'Stolen', Icons.report_problem_outlined),
      ('other', 'Other', Icons.more_horiz),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Note(
          'A reprint fee of UGX 20,000 applies and will be paid via Mobile Money.',
        ),
        const SizedBox(height: 12),
        ...reasons.map((r) {
          final selected = reason == r.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(r.$1),
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? kPrimary.withValues(alpha: 0.07)
                      : Colors.white,
                  border: Border.all(
                    color: selected ? kPrimary : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Row(
                  children: [
                    Icon(r.$3, color: selected ? kPrimary : Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? kPrimary : Colors.black87,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: kPrimary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        if (reason == 'other') ...[
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Please describe',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepWho extends ConsumerWidget {
  final bool isForDependant;
  final Dependant? selected;
  final ValueChanged<bool> onScopeChanged;
  final ValueChanged<Dependant> onDependantSelected;
  const _StepWho({
    required this.isForDependant,
    required this.selected,
    required this.onScopeChanged,
    required this.onDependantSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).member;
    final canViewDependants = ref.watch(canViewDependantsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ScopeTile(
                selected: !isForDependant,
                icon: Icons.person,
                label: 'Principal',
                subtitle: member != null
                    ? '${member.firstName} ${member.lastName}'
                    : '',
                onTap: () => onScopeChanged(false),
              ),
            ),
            if (canViewDependants) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ScopeTile(
                  selected: isForDependant,
                  icon: Icons.family_restroom,
                  label: 'Dependant',
                  subtitle: 'Spouse / Child',
                  onTap: () => onScopeChanged(true),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (isForDependant && canViewDependants)
          ref.watch(dependantsProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _Note('Could not load dependants: $e'),
                data: (list) {
                  if (list.isEmpty) {
                    return const _Note(
                        'No dependants found on your scheme.');
                  }
                  return Column(
                    children: list
                        .map((d) => _DependantTile(
                              dependant: d,
                              selected: selected?.memberNo == d.memberNo,
                              onTap: () => onDependantSelected(d),
                            ))
                        .toList(),
                  );
                },
              )
        else
          _Note(
            member != null
                ? 'A new card will be issued for ${member.firstName} ${member.lastName} (${member.memberNumber}).'
                : 'A new card will be issued for the principal.',
          ),
      ],
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ScopeTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.07) : Colors.white,
          border: Border.all(
            color: selected ? kPrimary : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? kPrimary : Colors.black54),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DependantTile extends StatelessWidget {
  final Dependant dependant;
  final bool selected;
  final VoidCallback onTap;
  const _DependantTile({
    required this.dependant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? kPrimary.withValues(alpha: 0.07)
                : Colors.white,
            border: Border.all(
              color: selected ? kPrimary : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: kPrimary.withValues(alpha: 0.1),
                child: Text(
                  dependant.name.isNotEmpty
                      ? dependant.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: kPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dependant.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${dependant.relation} • ${dependant.memberNo}',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: kPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPayment extends StatelessWidget {
  final String memberNumber;
  final TextEditingController txIdCtrl;
  final PlatformFile? proofFile;
  final VoidCallback onPickProof;
  final VoidCallback onClearProof;
  const _StepPayment({
    required this.memberNumber,
    required this.txIdCtrl,
    required this.proofFile,
    required this.onPickProof,
    required this.onClearProof,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: kPrimaryGradient,
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: const Row(
            children: [
              Icon(Icons.phone_android, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile Money Payment',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Amount: UGX 20,000',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MemberRefBox(memberNumber: memberNumber),
        const SizedBox(height: 16),
        const _PaymentInstructionsCard(
          title: 'Airtel Money',
          color: Color(0xFFE60000),
          icon: Icons.sim_card,
          steps: [
            'Dial *185# then press Yes',
            'Select 4 — Pay Bill',
            'Select 9 — Others',
            'Enter Business Number: 456456',
            'Enter Amount: 20000',
            'Enter Reference: Your Member Number (shown above)',
            'Enter your PIN to confirm',
          ],
        ),
        const SizedBox(height: 12),
        const _PaymentInstructionsCard(
          title: 'MTN Mobile Money',
          color: Color(0xFFFFCC00),
          textColor: Color(0xFF1A1A1A),
          icon: Icons.sim_card,
          steps: [
            'Dial *165*4*4#',
            'Merchant Code: Sanlam',
            'Payment Reference: Your Member Number (shown above)',
            'Enter Amount: 20000',
            'Enter your PIN to confirm',
          ],
        ),
        const SizedBox(height: 16),
        _ProofOfPaymentSection(
          txIdCtrl: txIdCtrl,
          proofFile: proofFile,
          onPickProof: onPickProof,
          onClearProof: onClearProof,
        ),
        const SizedBox(height: 12),
        const _Note(
          'After paying, attach a screenshot of the confirmation message OR enter the Mobile Money transaction ID, then tap Submit Request. We will verify your payment and process the card reprint.',
        ),
      ],
    );
  }
}

class _ProofOfPaymentSection extends StatelessWidget {
  final TextEditingController txIdCtrl;
  final PlatformFile? proofFile;
  final VoidCallback onPickProof;
  final VoidCallback onClearProof;
  const _ProofOfPaymentSection({
    required this.txIdCtrl,
    required this.proofFile,
    required this.onPickProof,
    required this.onClearProof,
  });

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: kPrimary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Proof of Payment',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Provide at least one of the following so we can verify your payment.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          // Screenshot
          if (proofFile == null)
            OutlinedButton.icon(
              onPressed: onPickProof,
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach payment screenshot'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: kPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proofFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          _humanSize(proofFile!.size),
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onClearProof,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR',
                    style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(height: 10),
          // Transaction ID
          TextField(
            controller: txIdCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Transaction ID',
              hintText: 'e.g. CI250507.1430.A12345',
              prefixIcon: const Icon(Icons.receipt_long_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRefBox extends StatelessWidget {
  final String memberNumber;
  const _MemberRefBox({required this.memberNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Payment Reference (Member Number)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                const SizedBox(height: 2),
                Text(
                  memberNumber.isEmpty ? '—' : memberNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, color: Color(0xFFB45309)),
            onPressed: memberNumber.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: memberNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Member number copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _PaymentInstructionsCard extends StatelessWidget {
  final String title;
  final Color color;
  final Color textColor;
  final IconData icon;
  final List<String> steps;
  const _PaymentInstructionsCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.steps,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadiusMd)),
            ),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: const TextStyle(fontSize: 13.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepSuccess extends StatelessWidget {
  final bool isForDependant;
  final Dependant? selectedDependant;
  final Member? principal;
  const _StepSuccess({
    required this.isForDependant,
    required this.selectedDependant,
    required this.principal,
  });

  @override
  Widget build(BuildContext context) {
    final name = isForDependant
        ? (selectedDependant?.name ?? '')
        : (principal != null
            ? '${principal!.firstName} ${principal!.lastName}'
            : '');
    final no = isForDependant
        ? (selectedDependant?.memberNo ?? '')
        : (principal?.memberNumber ?? '');
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: Colors.green, size: 56),
        ),
        const SizedBox(height: 20),
        const Text(
          'Request Submitted',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Your card reprint request for $name ($no) has been received. '
            'Once your Mobile Money payment is verified by the membership '
            'team, your card will be processed. You will receive an SMS '
            'and email confirmation.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: Colors.black87, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int step;
  final bool canNext;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;
  const _Footer({
    required this.step,
    required this.canNext,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 3) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(routeCardReprintHistory);
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Requests'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String label;
    if (step == 2) {
      label = submitting ? 'Submitting…' : 'Submit Request';
    } else {
      label = 'Continue';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            if (onBack != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (canNext && !submitting) ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
