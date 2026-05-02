import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../services/api_service.dart';
import 'reimbursement_history_screen.dart';

class ReimbursementScreen extends ConsumerStatefulWidget {
  const ReimbursementScreen({super.key});

  @override
  ConsumerState<ReimbursementScreen> createState() =>
      _ReimbursementScreenState();
}

class _ReimbursementScreenState extends ConsumerState<ReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  String _payoutMethod = 'mobile_money';
  PlatformFile? _invoice;
  PlatformFile? _report;
  bool _submitting = false;

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _reasonCtrl.dispose();
    _amountCtrl.dispose();
    _accountNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required bool invoice}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        if (invoice) {
          _invoice = result.files.first;
        } else {
          _report = result.files.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice attachment is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      MultipartFile invoiceMpf;
      if (_invoice!.bytes != null) {
        invoiceMpf = MultipartFile.fromBytes(
          _invoice!.bytes!,
          filename: _invoice!.name,
        );
      } else {
        invoiceMpf = await MultipartFile.fromFile(
          _invoice!.path!,
          filename: _invoice!.name,
        );
      }

      MultipartFile? reportMpf;
      if (_report != null) {
        if (_report!.bytes != null) {
          reportMpf = MultipartFile.fromBytes(
            _report!.bytes!,
            filename: _report!.name,
          );
        } else {
          reportMpf = await MultipartFile.fromFile(
            _report!.path!,
            filename: _report!.name,
          );
        }
      }

      final formData = FormData.fromMap({
        'hospitalName': _hospitalCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
        if (_amountCtrl.text.trim().isNotEmpty)
          'amount': _amountCtrl.text.trim(),
        'payoutMethod': _payoutMethod,
        'payoutAccountName': _accountNameCtrl.text.trim(),
        if (_payoutMethod == 'mobile_money')
          'payoutPhone': _phoneCtrl.text.trim(),
        if (_payoutMethod == 'bank') ...{
          'payoutBankName': _bankNameCtrl.text.trim(),
          'payoutAccountNumber': _accountNumberCtrl.text.trim(),
          if (_branchCtrl.text.trim().isNotEmpty)
            'payoutBranch': _branchCtrl.text.trim(),
        },
        'invoice': invoiceMpf,
        if (reportMpf != null) 'report': reportMpf,
      });

      await dio.post(
        '/reimbursements',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (!mounted) return;
      // Refresh history list and navigate user to it
      ref.invalidate(reimbursementHistoryProvider);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Request Submitted'),
          content: const Text(
            'Your reimbursement request has been received. The Sanlam Care '
            'team will review it and notify you once payment is processed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('View My Requests'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Replace this form with the history screen so user can track status
      context.pushReplacement(routeReimbursementHistory);
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
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'Request Reimbursement',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'My Requests',
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => context.push(routeReimbursementHistory),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Note(
                'Use this form when you received care at a hospital that is not '
                "in Sanlam's network and need to be reimbursed. The invoice "
                'attachment is mandatory.',
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Hospital details'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hospitalCtrl,
                decoration:
                    _dec('Hospital name', Icons.local_hospital_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 4,
                decoration: _dec(
                  'Reason / what was treated',
                  Icons.medical_information_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec(
                    'Amount paid (UGX, optional)', Icons.payments_outlined),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Attachments'),
              const SizedBox(height: 8),
              _AttachmentTile(
                title: 'Invoice / Receipt',
                subtitle: 'Required • PDF or image',
                file: _invoice,
                required: true,
                onTap: () => _pickFile(invoice: true),
                onClear: () => setState(() => _invoice = null),
              ),
              const SizedBox(height: 8),
              _AttachmentTile(
                title: 'Medical Report / Summary',
                subtitle: 'Optional • PDF or image',
                file: _report,
                required: false,
                onTap: () => _pickFile(invoice: false),
                onClear: () => setState(() => _report = null),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Payout details'),
              const SizedBox(height: 4),
              const Text(
                'How should Sanlam pay you back?',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MethodChip(
                      selected: _payoutMethod == 'mobile_money',
                      icon: Icons.phone_android,
                      label: 'Mobile Money',
                      sublabel: 'MTN / Airtel',
                      brandColor: const Color(0xFFFFB400),
                      onTap: () =>
                          setState(() => _payoutMethod = 'mobile_money'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MethodChip(
                      selected: _payoutMethod == 'bank',
                      icon: Icons.account_balance,
                      label: 'Bank Account',
                      sublabel: 'Direct deposit',
                      brandColor: const Color(0xFF1E40AF),
                      onTap: () => setState(() => _payoutMethod = 'bank'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNameCtrl,
                decoration: _dec(
                  _payoutMethod == 'mobile_money'
                      ? 'Names on the Mobile Money line'
                      : 'Account holder name',
                  Icons.person_outline,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              if (_payoutMethod == 'mobile_money')
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _dec(
                    'Mobile Money number',
                    Icons.phone_outlined,
                    hint: 'e.g. 0772 123 456',
                  ),
                  validator: (v) {
                    final p = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (p.length < 9) return 'Enter a valid phone number';
                    return null;
                  },
                )
              else ...[
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration:
                      _dec('Bank name', Icons.account_balance_outlined),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Account number', Icons.numbers),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _branchCtrl,
                  decoration: _dec(
                      'Branch (optional)', Icons.location_city_outlined),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Reimbursement Request',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: kText),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color brandColor;
  final VoidCallback onTap;
  const _MethodChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.brandColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? brandColor.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: selected ? brandColor : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selected
                      ? [brandColor, brandColor.withValues(alpha: 0.7)]
                      : [
                          Colors.grey.shade200,
                          Colors.grey.shade100,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: brandColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.black54,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? brandColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? brandColor.withValues(alpha: 0.7)
                    : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final PlatformFile? file;
  final bool required;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _AttachmentTile({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.required,
    required this.onTap,
    required this.onClear,
  });

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final has = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: has ? kPrimary : Colors.grey.shade300,
            width: has ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (has ? kPrimary : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                has ? Icons.insert_drive_file : Icons.upload_file,
                color: has ? kPrimary : Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (required)
                        const Text(
                          '*',
                          style: TextStyle(
                              color: kError, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has
                        ? '${file!.name}  •  ${_humanSize(file!.size)}'
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: has ? kPrimary : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (has)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              )
            else
              const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
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
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// Keep dart:io import referenced (used implicitly via PlatformFile.path)
// ignore: unused_element
typedef _Unused = File;
