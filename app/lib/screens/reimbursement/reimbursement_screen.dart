import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../services/api_service.dart';
import 'reimbursement_history_screen.dart';
import '../../core/app_colors.dart';

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
  final _approvalReferenceCtrl = TextEditingController();

  String _payoutMethod = 'bank';
  // 'in_app' = pick an approved in-app authorization
  // 'email'  = attach the Sancare approval email/letter + reference
  String _approvalPath = 'in_app';
  PlatformFile? _invoice;
  PlatformFile? _report;
  PlatformFile? _approvalEmail;
  bool _submitting = false;

  bool _loadingAuths = true;
  List<Map<String, dynamic>> _approvedAuths = [];
  String? _selectedAuthId;

  @override
  void initState() {
    super.initState();
    _loadApprovedAuths();
  }

  Future<void> _loadApprovedAuths() async {
    try {
      final resp = await dio.get('/authorizations/mine');
      final all = (resp.data as List).cast<Map<String, dynamic>>();
      // Hospital visits only — pharmacy auths aren't reimbursable here.
      final approved = all.where((a) {
        final status = (a['status'] ?? '').toString();
        final providerType = (a['provider_type'] ?? '').toString();
        return status == 'approved' && providerType != 'pharmacy';
      }).toList();
      if (!mounted) return;
      setState(() {
        _approvedAuths = approved;
        _loadingAuths = false;
        // Default path: in-app if any approved auths exist, otherwise email.
        _approvalPath = approved.isNotEmpty ? 'in_app' : 'email';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _approvedAuths = [];
        _loadingAuths = false;
        _approvalPath = 'email';
      });
    }
  }

  void _onSelectAuth(String? id) {
    setState(() {
      _selectedAuthId = id;
      if (id != null) {
        final auth = _approvedAuths.firstWhere(
          (a) => a['id'].toString() == id,
          orElse: () => const {},
        );
        final name = (auth['provider_name'] ?? '').toString();
        if (name.isNotEmpty) _hospitalCtrl.text = name;
      }
    });
  }

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
    _approvalReferenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required String slot}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        switch (slot) {
          case 'invoice':
            _invoice = result.files.first;
            break;
          case 'report':
            _report = result.files.first;
            break;
          case 'approvalEmail':
            _approvalEmail = result.files.first;
            break;
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

    // Enforce the Sancare authorization gate.
    if (_approvalPath == 'in_app') {
      if (_selectedAuthId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select the approved authorization this reimbursement relates to',
            ),
          ),
        );
        return;
      }
    } else {
      if (_approvalEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Attach the Sancare approval email/letter you received',
            ),
          ),
        );
        return;
      }
      if (_approvalReferenceCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add a Sancare approval reference (officer name or email subject)',
            ),
          ),
        );
        return;
      }
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

      MultipartFile? approvalMpf;
      if (_approvalPath == 'email' && _approvalEmail != null) {
        if (_approvalEmail!.bytes != null) {
          approvalMpf = MultipartFile.fromBytes(
            _approvalEmail!.bytes!,
            filename: _approvalEmail!.name,
          );
        } else {
          approvalMpf = await MultipartFile.fromFile(
            _approvalEmail!.path!,
            filename: _approvalEmail!.name,
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
        'approvalPath': _approvalPath,
        if (_approvalPath == 'in_app') 'authorizationId': _selectedAuthId,
        if (_approvalPath == 'email')
          'approvalReference': _approvalReferenceCtrl.text.trim(),
        'invoice': invoiceMpf,
        if (reportMpf != null) 'report': reportMpf,
        if (approvalMpf != null) 'approvalEmail': approvalMpf,
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
        builder: (dialogCtx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Request Submitted'),
          content: const Text(
            'Your reimbursement request has been received. The Sanlam Care '
            'team will review it and notify you once payment is processed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('View My Requests'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Replace this form with the history screen so user can track status.
      // Use go() rather than pushReplacement() so go_router cleanly swaps
      // the inner ShellRoute child instead of leaving the form in the stack.
      context.go(routeReimbursementHistory);
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
      backgroundColor: context.c.bg,
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
                'Reimbursement is only available for visits that were '
                'pre-authorized by Sancare. Choose the authorization that '
                'covers this visit, then attach your invoice.',
              ),
              const SizedBox(height: 16),
              _ApprovalPathSection(
                loading: _loadingAuths,
                approvalPath: _approvalPath,
                approvedAuths: _approvedAuths,
                selectedAuthId: _selectedAuthId,
                approvalEmail: _approvalEmail,
                approvalReferenceCtrl: _approvalReferenceCtrl,
                onPathChanged: (p) => setState(() {
                  _approvalPath = p;
                  if (p == 'in_app') {
                    _approvalEmail = null;
                  } else {
                    _selectedAuthId = null;
                  }
                }),
                onSelectAuth: _onSelectAuth,
                onPickApprovalEmail: () => _pickFile(slot: 'approvalEmail'),
                onClearApprovalEmail: () =>
                    setState(() => _approvalEmail = null),
                onRequestAuthorization: () =>
                    context.push('/authorizations/request'),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Hospital details'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hospitalCtrl,
                readOnly:
                    _approvalPath == 'in_app' && _selectedAuthId != null,
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
                onTap: () => _pickFile(slot: 'invoice'),
                onClear: () => setState(() => _invoice = null),
              ),
              const SizedBox(height: 8),
              _AttachmentTile(
                title: 'Medical Report / Summary',
                subtitle: 'Optional • PDF or image',
                file: _report,
                required: false,
                onTap: () => _pickFile(slot: 'report'),
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
              // Payout is bank only.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.account_balance,
                        color: Color(0xFF1E40AF), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bank Account (Direct deposit)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNameCtrl,
                decoration:
                    _dec('Account holder name', Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
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
                decoration:
                    _dec('Branch (optional)', Icons.location_city_outlined),
              ),
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
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: context.c.text),
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
          color: context.c.cardBg,
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

class _ApprovalPathSection extends StatelessWidget {
  final bool loading;
  final String approvalPath; // 'in_app' | 'email'
  final List<Map<String, dynamic>> approvedAuths;
  final String? selectedAuthId;
  final PlatformFile? approvalEmail;
  final TextEditingController approvalReferenceCtrl;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<String?> onSelectAuth;
  final VoidCallback onPickApprovalEmail;
  final VoidCallback onClearApprovalEmail;
  final VoidCallback onRequestAuthorization;

  const _ApprovalPathSection({
    required this.loading,
    required this.approvalPath,
    required this.approvedAuths,
    required this.selectedAuthId,
    required this.approvalEmail,
    required this.approvalReferenceCtrl,
    required this.onPathChanged,
    required this.onSelectAuth,
    required this.onPickApprovalEmail,
    required this.onClearApprovalEmail,
    required this.onRequestAuthorization,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Sancare authorization'),
        const SizedBox(height: 4),
        const Text(
          'How was this visit pre-authorized?',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PathChip(
                selected: approvalPath == 'in_app',
                icon: Icons.verified_outlined,
                label: 'In-app authorization',
                sublabel: 'Pick an approved request',
                onTap: () => onPathChanged('in_app'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PathChip(
                selected: approvalPath == 'email',
                icon: Icons.mark_email_read_outlined,
                label: 'Email approval',
                sublabel: 'Attach Sancare email',
                onTap: () => onPathChanged('email'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (approvalPath == 'in_app')
          _InAppAuthPicker(
            loading: loading,
            approvedAuths: approvedAuths,
            selectedAuthId: selectedAuthId,
            onChanged: onSelectAuth,
            onRequestAuthorization: onRequestAuthorization,
          )
        else
          _EmailApprovalBlock(
            approvalEmail: approvalEmail,
            approvalReferenceCtrl: approvalReferenceCtrl,
            onPick: onPickApprovalEmail,
            onClear: onClearApprovalEmail,
          ),
      ],
    );
  }
}

class _PathChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  const _PathChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color:
              selected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? kPrimary : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? kPrimary : Colors.black54, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: selected ? kPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InAppAuthPicker extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> approvedAuths;
  final String? selectedAuthId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRequestAuthorization;
  const _InAppAuthPicker({
    required this.loading,
    required this.approvedAuths,
    required this.selectedAuthId,
    required this.onChanged,
    required this.onRequestAuthorization,
  });

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.c.cardBg,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Row(
          children: const [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Loading your approved authorizations…'),
          ],
        ),
      );
    }
    if (approvedAuths.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No approved authorizations on file',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Reimbursements require prior Sancare authorization. Please '
              'submit an authorization request first; once approved (and '
              'after you have visited the facility) come back here to '
              'submit your invoice.',
              style:
                  TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRequestAuthorization,
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('Request Pre-Authorization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: selectedAuthId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Approved authorization for this visit',
        prefixIcon: const Icon(Icons.verified_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      ),
      items: approvedAuths.map((a) {
        final id = a['id'].toString();
        final name = (a['provider_name'] ?? 'Provider').toString();
        final type = (a['request_type'] ?? '').toString().replaceAll('_', ' ');
        final date = _fmtDate(a['scheduled_date']?.toString());
        final subtitle =
            [if (type.isNotEmpty) type, if (date.isNotEmpty) date].join(' • ');
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            subtitle.isEmpty ? name : '$name  ($subtitle)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Select an authorization' : null,
    );
  }
}

class _EmailApprovalBlock extends StatelessWidget {
  final PlatformFile? approvalEmail;
  final TextEditingController approvalReferenceCtrl;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _EmailApprovalBlock({
    required this.approvalEmail,
    required this.approvalReferenceCtrl,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttachmentTile(
          title: 'Sancare approval email / letter',
          subtitle: 'Required • PDF or screenshot',
          file: approvalEmail,
          required: true,
          onTap: onPick,
          onClear: onClear,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: approvalReferenceCtrl,
          decoration: InputDecoration(
            labelText: 'Sancare officer / approval reference',
            hintText: 'e.g. Approved by Jane (email 12 May)',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }
}
