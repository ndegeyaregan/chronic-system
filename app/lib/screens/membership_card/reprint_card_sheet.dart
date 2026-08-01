import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../models/dependant.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependants_provider.dart';
import '../../services/api_service.dart';
import 'card_reprint_history_screen.dart';

/// Tracks progress through the Onafriq push-payment flow once the member
/// submits their Mobile Money number.
enum _PaymentPhase { idle, waitingForPin, succeeded, failed }

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
  final _phoneCtrl = TextEditingController();
  bool _isForDependant = false;
  Dependant? _selectedDependant;
  bool _submitting = false;

  _PaymentPhase _paymentPhase = _PaymentPhase.idle;
  String? _requestId;
  Timer? _pollTimer;
  int _pollElapsedSeconds = 0;
  static const _pollTimeoutSeconds = 120;

  @override
  void initState() {
    super.initState();
    _reasonNotesCtrl.addListener(_refresh);
    _phoneCtrl.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _reasonNotesCtrl.removeListener(_refresh);
    _reasonNotesCtrl.dispose();
    _phoneCtrl.removeListener(_refresh);
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _step0Valid {
    if (_reason == null) return false;
    if (_reason == 'other' && _reasonNotesCtrl.text.trim().isEmpty)
      return false;
    return true;
  }

  bool get _step1Valid {
    if (_isForDependant) return _selectedDependant != null;
    return true;
  }

  bool get _step2Valid {
    return _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length >= 9;
  }

  void _next() {
    if (_step == 0 && !_step0Valid) return;
    if (_step == 1 && !_step1Valid) return;
    if (_step == 2 && !_step2Valid) return;
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, 3));

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

      final res = await dio.post('/card-reprints', data: {
        'targetMemberNo': targetMemberNo,
        'targetMemberName': targetMemberName,
        'targetRelation': targetRelation,
        'isForDependant': _isForDependant.toString(),
        'reason': _reason,
        'reasonNotes': _reasonNotesCtrl.text.trim(),
        'paymentPhone': _phoneCtrl.text.trim(),
      });
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        _requestId = res.data['id'] as String?;
        setState(() {
          _step = 3;
          _paymentPhase = _PaymentPhase.waitingForPin;
        });
        _startPolling();
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

  /// Polls the backend for the Onafriq pay-in result every few seconds
  /// while the member is asked to enter their Mobile Money PIN.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollElapsedSeconds = 0;
    final requestId = _requestId;
    if (requestId == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollElapsedSeconds += 3;
      if (_pollElapsedSeconds >= _pollTimeoutSeconds) {
        timer.cancel();
        if (mounted) setState(() => _paymentPhase = _PaymentPhase.failed);
        return;
      }
      try {
        final res = await dio.get('/card-reprints/$requestId/payment-status');
        final paymentStatus = res.data['paymentStatus'] as String?;
        if (paymentStatus == 'completed') {
          timer.cancel();
          ref.invalidate(cardReprintHistoryProvider);
          if (mounted) setState(() => _paymentPhase = _PaymentPhase.succeeded);
        } else if (paymentStatus == 'failed' ||
            paymentStatus == 'expired' ||
            paymentStatus == 'reversed') {
          timer.cancel();
          if (mounted) setState(() => _paymentPhase = _PaymentPhase.failed);
        }
        // Anything else (pending/instructions_sent/processing_started) —
        // keep polling.
      } catch (_) {
        // Transient network error — keep polling rather than failing outright.
      }
    });
  }

  void _retryPayment() {
    _pollTimer?.cancel();
    setState(() {
      _step = 2;
      _paymentPhase = _PaymentPhase.idle;
    });
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
            decoration: BoxDecoration(
              color: context.c.cardBg,
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
                _Header(step: _step, paymentPhase: _paymentPhase),
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
                      2 => _StepPaymentPhone(phoneCtrl: _phoneCtrl),
                      _ => switch (_paymentPhase) {
                          _PaymentPhase.failed => const _StepPaymentFailed(),
                          _PaymentPhase.succeeded => _StepSuccess(
                              isForDependant: _isForDependant,
                              selectedDependant: _selectedDependant,
                              principal: ref.read(authProvider).member,
                            ),
                          _ => _StepWaitingForPin(
                              phone: _phoneCtrl.text.trim(),
                            ),
                        },
                    },
                  ),
                ),
                _Footer(
                  step: _step,
                  paymentPhase: _paymentPhase,
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
                  onRetry: _retryPayment,
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
  final _PaymentPhase paymentPhase;
  const _Header({required this.step, required this.paymentPhase});

  @override
  Widget build(BuildContext context) {
    final title = step < 3
        ? const [
            'Reason for Reprint',
            'Who is the card for?',
            'Mobile Money Payment',
          ][step]
        : switch (paymentPhase) {
            _PaymentPhase.failed => 'Payment Not Completed',
            _PaymentPhase.succeeded => 'Request Submitted',
            _ => 'Approve Payment',
          };
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
                  title,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    return const _Note('No dependants found on your scheme.');
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kPrimary.withValues(alpha: 0.07) : Colors.white,
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
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${dependant.relation} • ${dependant.memberNo}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: kPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPaymentPhone extends StatelessWidget {
  final TextEditingController phoneCtrl;
  const _StepPaymentPhone({required this.phoneCtrl});

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
          child: Row(
            children: [
              const Icon(Icons.phone_android, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile Money Payment',
                        style: TextStyle(
                            color: context.c.cardBg,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('Amount: UGX 20,000',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Mobile Money Number',
            hintText: 'e.g. +256 7XX XXX XXX',
            prefixIcon: const Icon(Icons.phone_iphone_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Note(
          'We\'ll send a payment request to this number for UGX 20,000. '
          'You\'ll get a prompt on your phone — just enter your Mobile '
          'Money PIN to approve it. No screenshots needed.',
        ),
      ],
    );
  }
}

class _StepWaitingForPin extends StatelessWidget {
  final String phone;
  const _StepWaitingForPin({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check Your Phone',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'We sent a payment request of UGX 20,000 to ${phone.isEmpty ? 'your number' : phone}. '
            'Enter your Mobile Money PIN on the prompt to approve it.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),
        const _Note(
          'This can take up to a couple of minutes. Keep this screen open '
          'until it confirms.',
        ),
      ],
    );
  }
}

class _StepPaymentFailed extends StatelessWidget {
  const _StepPaymentFailed();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kError.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: kError, size: 56),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Not Completed',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'The payment request timed out, was declined, or expired before '
            'it was approved. You can try again with the same or a '
            'different number.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
      ],
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
          child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Received',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Your Mobile Money payment for the $name ($no) card reprint has '
            'been confirmed. Our membership team will process your new '
            'card, and you\'ll get an SMS and email confirmation.',
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
  final _PaymentPhase paymentPhase;
  final bool canNext;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  const _Footer({
    required this.step,
    required this.paymentPhase,
    required this.canNext,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 3 && paymentPhase == _PaymentPhase.waitingForPin) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    }

    if (step == 3 && paymentPhase == _PaymentPhase.failed) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (step == 3) {
      // succeeded
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
