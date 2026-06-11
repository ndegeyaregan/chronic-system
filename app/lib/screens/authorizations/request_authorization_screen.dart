import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../models/authorization_request.dart';
import '../../models/pharmacy.dart';
import '../../providers/authorizations_provider.dart';
import '../../providers/pharmacies_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../core/app_colors.dart';

class RequestAuthorizationScreen extends ConsumerStatefulWidget {
  final String? medicationId;
  final String? medicationName;

  const RequestAuthorizationScreen({
    super.key,
    this.medicationId,
    this.medicationName,
  });

  @override
  ConsumerState<RequestAuthorizationScreen> createState() =>
      _RequestAuthorizationScreenState();
}

class _RequestAuthorizationScreenState
    extends ConsumerState<RequestAuthorizationScreen> {
  AuthRequestType _type = AuthRequestType.medicationRefill;
  String _providerType = 'pharmacy';
  Pharmacy? _selectedPharmacy;
  DateTime? _scheduledDate;
  final _notesCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  bool _submitting = false;
  PlatformFile? _attachment;

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'doc', 'docx'
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _attachment = result.files.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select scheduled date',
    );
    if (d != null) setState(() => _scheduledDate = d);
  }

  String _typeToApiString(AuthRequestType t) {
    switch (t) {
      case AuthRequestType.procedure:
        return 'procedure';
      case AuthRequestType.surgery:
        return 'surgery';
      case AuthRequestType.followUp:
        return 'follow_up';
      default:
        return 'medication_refill';
    }
  }

  Future<void> _submit() async {
    if (_scheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a scheduled date.'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }

    final providerName = _providerType == 'pharmacy'
        ? _selectedPharmacy?.name
        : _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim();

    final providerId =
        (_providerType == 'pharmacy' && _selectedPharmacy?.id != null && _selectedPharmacy!.id.isNotEmpty)
            ? _selectedPharmacy!.id
            : null;

    setState(() => _submitting = true);
    final success =
        await ref.read(authorizationsProvider.notifier).submitRequest(
              requestType: _typeToApiString(_type),
              providerType: _providerType,
              providerId: providerId,
              providerName: providerName,
              scheduledDate: _scheduledDate!,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
              memberMedicationId: widget.medicationId,
              attachment: _attachment,
            );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Authorization request submitted! Sanlam will review it shortly.'),
          backgroundColor: kSuccess,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit request. Please try again.'),
          backgroundColor: kError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyState = ref.watch(pharmaciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Pre-Authorization'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: kPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Submit a pre-authorization so Sanlam can approve your medication '
                      'pickup or procedure before you visit the facility. This saves you '
                      'waiting time — on the day you just collect.',
                      style: TextStyle(
                          fontSize: 13,
                          color: kPrimary.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Medication context (pre-filled)
            if (widget.medicationName != null) ...[
              _Label('Medication'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: kSuccess.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        color: kSuccess, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      widget.medicationName!,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Request type
            _Label('Request Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<AuthRequestType>(
              value: _type,
              decoration: _deco(Icons.assignment_outlined),
              items: const [
                DropdownMenuItem(
                    value: AuthRequestType.medicationRefill,
                    child: Text('Medication Refill')),
                DropdownMenuItem(
                    value: AuthRequestType.procedure,
                    child: Text('Procedure')),
                DropdownMenuItem(
                    value: AuthRequestType.surgery, child: Text('Surgery')),
                DropdownMenuItem(
                    value: AuthRequestType.followUp,
                    child: Text('Follow-Up Visit')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _type = v;
                  _providerType = v == AuthRequestType.medicationRefill
                      ? 'pharmacy'
                      : 'hospital';
                });
              },
            ),
            const SizedBox(height: 20),

            // Provider type toggle
            _Label('Provider Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'Pharmacy',
                  icon: Icons.local_pharmacy_outlined,
                  selected: _providerType == 'pharmacy',
                  onTap: () => setState(() => _providerType = 'pharmacy'),
                ),
                const SizedBox(width: 10),
                _TypeChip(
                  label: 'Hospital',
                  icon: Icons.local_hospital_outlined,
                  selected: _providerType == 'hospital',
                  onTap: () => setState(() => _providerType = 'hospital'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Provider picker
            if (_providerType == 'pharmacy') ...[
              _Label('Select Pharmacy'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPharmacy?.id.isEmpty == true
                    ? null
                    : _selectedPharmacy?.id,
                hint: const Text('Choose a pharmacy'),
                decoration: _deco(Icons.storefront_outlined),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...pharmacyState.pharmacies.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      )),
                ],
                onChanged: (id) => setState(() {
                  _selectedPharmacy = id == null
                      ? null
                      : pharmacyState.pharmacies
                          .firstWhere((p) => p.id == id);
                }),
              ),
            ] else ...[
              _Label('Hospital / Facility (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hospitalCtrl,
                decoration: _deco(Icons.local_hospital_outlined).copyWith(
                  hintText: 'e.g. Heart Institute Uganda',
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Scheduled date
            _Label('Scheduled Date *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: context.c.subtext),
                    const SizedBox(width: 10),
                    Text(
                      _scheduledDate == null
                          ? 'Select date'
                          : DateFormat('EEEE, d MMMM yyyy')
                              .format(_scheduledDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            _scheduledDate == null ? context.c.subtext : context.c.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            _Label('Additional Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g. Doctor recommended this refill, procedure details...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.c.border)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // Optional attachment
            _Label('Attachment (optional)'),
            const SizedBox(height: 4),
            Text(
              'Attach a prescription or supporting document (PDF, image or DOC).',
              style: TextStyle(color: context.c.subtext, fontSize: 12),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickAttachment,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _attachment == null
                          ? context.c.border
                          : kPrimary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachment == null
                          ? Icons.attach_file_outlined
                          : Icons.insert_drive_file_outlined,
                      color: _attachment == null ? context.c.subtext : kPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachment?.name ?? 'Choose file',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _attachment == null
                                  ? context.c.subtext
                                  : context.c.text,
                            ),
                          ),
                          if (_attachment != null)
                            Text(
                              '${(_attachment!.size / 1024).toStringAsFixed(0)} KB',
                              style: TextStyle(
                                  fontSize: 11, color: context.c.subtext),
                            ),
                        ],
                      ),
                    ),
                    if (_attachment != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _attachment = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            AppButton(
              label: 'Submit Request',
              onPressed: _submit,
              isLoading: _submitting,
              leadingIcon: Icons.send_outlined,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, color: context.c.subtext, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.c.border)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: context.c.text));
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kPrimary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? kPrimary : context.c.border,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? kPrimary : context.c.subtext),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? kPrimary : context.c.text,
                ),
              ),
            ],
          ),
        ),
      );
}
