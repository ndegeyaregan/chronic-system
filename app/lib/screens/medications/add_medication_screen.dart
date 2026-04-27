import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medications_provider.dart';
import '../../providers/pharmacies_provider.dart';
import '../../models/pharmacy.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/media_attachment_widget.dart';
import '../../services/auth_service.dart';
import '../../utils/medications_data.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  String _frequency = 'Once daily';
  String? _selectedCondition;
  TimeOfDay? _startTime;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _prescriptionFileName;
  final _mediaController = MediaAttachmentController();
  // Pharmacy & refill
  Pharmacy? _selectedPharmacy;
  int? _refillIntervalDays; // null = no refill tracking

  List<String> _nameSuggestions = [];
  bool _loadingSuggestions = false;
  bool _suppressSearch = false;  // prevents re-search when selecting a suggestion
  Timer? _searchDebounce;

  final _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'Every 6 hours',
    'Every 8 hours',
    'Every 12 hours',
    'Weekly',
    'As needed',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _nameSuggestions = []);
        });
      }
    });
    // Load pharmacies for the picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pharmaciesProvider.notifier).fetchPharmacies();
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    _nameFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    if (_suppressSearch) return;  // skip when selection was just made
    _searchDebounce?.cancel();
    final query = _nameCtrl.text.trim();
    if (query.length < 2) {
      setState(() {
        _nameSuggestions = [];
        _loadingSuggestions = false;
      });
      return;
    }

    // Show local results instantly while waiting for backend
    final localResults = searchMedications(query, limit: 8);
    setState(() {
      _nameSuggestions = localResults;
      _loadingSuggestions = true;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _fetchMedicationSuggestions(query),
    );
  }

  Future<void> _fetchMedicationSuggestions(String query) async {
    try {
      final token = await authService.getToken();
      final response = await Dio().get(
        '$kBaseUrl/medications/search',
        queryParameters: {'q': query},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final results = (response.data as List).cast<String>();
      if (mounted) {
        setState(() {
          _nameSuggestions = results.isNotEmpty
              ? results.take(15).toList()
              : searchMedications(query, limit: 15);
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      // Backend unreachable — fall back to local list
      if (mounted) {
        setState(() {
          _nameSuggestions = searchMedications(query, limit: 15);
          _loadingSuggestions = false;
        });
      }
    }
  }

  List<String> _computeDoseTimes() {
    if (_startTime == null) return [];
    final total = switch (_frequency) {
      'Once daily' => 1,
      'Twice daily' => 2,
      'Three times daily' => 3,
      'Four times daily' => 4,
      'Every 6 hours' => 4,
      'Every 8 hours' => 3,
      'Every 12 hours' => 2,
      _ => 1,
    };
    final intervalHours = total > 1 ? 24 ~/ total : 24;
    return List.generate(total, (i) {
      final h = (_startTime!.hour + i * intervalHours) % 24;
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h % 12 == 0 ? 12 : h % 12;
      final min = _startTime!.minute.toString().padLeft(2, '0');
      return '$hour12:$min $period';
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _prescriptionFileName = result.files.first.name);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    // Fields are optional — user may attach media instead of filling details
    final hasMedia = _mediaController.hasAudio ||
        _mediaController.hasVideo ||
        _mediaController.hasPhoto ||
        _prescriptionFileName != null;
    final hasName = _nameCtrl.text.trim().isNotEmpty;

    if (!hasName && !hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please enter a medication name or attach a photo/voice/video of the prescription.'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }

    final startTimeStr = _startTime != null
        ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
        : null;
    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);

    final success =
        await ref.read(medicationsProvider.notifier).addMedication({
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      if (_dosageCtrl.text.trim().isNotEmpty) 'dosage': _dosageCtrl.text.trim(),
      'frequency': _frequency,
      'start_date': startDateStr,
      if (startTimeStr != null) 'start_time': startTimeStr,
      if (_endDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
      if (_instructionsCtrl.text.trim().isNotEmpty)
        'instructions': _instructionsCtrl.text.trim(),
      if (_selectedCondition != null) 'condition': _selectedCondition,
      if (_selectedPharmacy != null) 'pharmacy_id': _selectedPharmacy!.id,
      if (_refillIntervalDays != null) 'refill_interval_days': _refillIntervalDays,
    }, media: _mediaController);
    if (success && mounted) {
      // Schedule a daily reminder if a start time is provided
      if (_startTime != null && _nameCtrl.text.trim().isNotEmpty) {
        final meds = ref.read(medicationsProvider).currentMeds;
        final medId = meds.isEmpty ? 1000 : meds.length + 1000;
        NotificationService.scheduleMedicationReminder(
          id: medId,
          medicationName: _nameCtrl.text.trim(),
          hour: _startTime!.hour,
          minute: _startTime!.minute,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication added successfully!'),
          backgroundColor: kSuccess,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).member;
    final state = ref.watch(medicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Medication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Medication Name with Autocomplete ──────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medication Name',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kText),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    focusNode: _nameFocusNode,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Search or type medication name',
                      prefixIcon: const Icon(Icons.medication_outlined,
                          color: kSubtext),
                      suffixIcon: _loadingSuggestions
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kPrimary),
                              ),
                            )
                          : null,
                    ),
                    validator: null,
                  ),
                  if (_nameSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        boxShadow: kShadowSm,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _nameSuggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          final suggestion = _nameSuggestions[i];
                          return Listener(
                            onPointerDown: (_) {
                              // onPointerDown fires before focus changes,
                              // so the suggestion can be captured before
                              // the text field blur-close timer runs.
                              _suppressSearch = true;
                              _nameCtrl.text = suggestion;
                              _suppressSearch = false;
                              _searchDebounce?.cancel();
                              setState(() {
                                _nameSuggestions = [];
                                _loadingSuggestions = false;
                              });
                              // Move cursor to end of text
                              _nameCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _nameCtrl.text.length),
                              );
                              Future.microtask(() => _nameFocusNode.unfocus());
                            },
                            child: InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.medication_outlined,
                                        size: 16, color: kSubtext),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(suggestion,
                                          style: const TextStyle(fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_nameCtrl.text.length >= 2 &&
                      !_loadingSuggestions &&
                      _nameSuggestions.isEmpty &&
                      _nameFocusNode.hasFocus)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No suggestions found — your typed name will be used.',
                        style: const TextStyle(
                            fontSize: 11, color: kSubtext),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Dosage',
                hint: 'e.g. 500mg',
                controller: _dosageCtrl,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequency',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kText),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.schedule_outlined,
                          color: kSubtext),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kBorder)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: _frequencies
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _frequency = v!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Start Date picker ──────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kText),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickStartDate,
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
                            DateFormat('dd MMM yyyy').format(_startDate),
                            style: const TextStyle(
                                color: kText, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── End Date picker (optional) ─────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'End Date',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kText),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '(optional — leave blank for ongoing)',
                        style: TextStyle(fontSize: 11, color: kSubtext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickEndDate,
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
                          const Icon(Icons.event_outlined,
                              color: kSubtext, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _endDate != null
                                  ? DateFormat('dd MMM yyyy').format(_endDate!)
                                  : 'Ongoing (no end date)',
                              style: TextStyle(
                                color: _endDate != null ? kText : kSubtext,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_endDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _endDate = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: kSubtext),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Start Time picker ──────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Time (first dose)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kText),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
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
                          const Icon(Icons.access_time_outlined,
                              color: kSubtext, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'Select start time',
                            style: TextStyle(
                              color:
                                  _startTime != null ? kText : kSubtext,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_startTime != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Dose times: ${_computeDoseTimes().join(', ')}',
                      style: const TextStyle(
                          fontSize: 12, color: kPrimary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // ── Prescription upload ────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            color: kPrimary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('📎',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _prescriptionFileName ??
                                  'Attach Prescription',
                              style: TextStyle(
                                color: _prescriptionFileName != null
                                    ? kText
                                    : kSubtext,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (_prescriptionFileName != null)
                            GestureDetector(
                              onTap: () => setState(
                                  () => _prescriptionFileName = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: kSubtext),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (member?.conditions.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Related Condition (optional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kText),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      hint: const Text('Select condition'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                            Icons.local_hospital_outlined,
                            color: kSubtext),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kBorder)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None')),
                        ...member!.conditions.map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCondition = v),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // ── Pharmacy Provider ────────────────────────────────────────────
              _PharmacyPicker(
                selected: _selectedPharmacy,
                onChanged: (p) => setState(() => _selectedPharmacy = p),
              ),
              const SizedBox(height: 16),
              // ── Refill Reminder ──────────────────────────────────────────────
              _RefillIntervalPicker(
                value: _refillIntervalDays,
                onChanged: (v) => setState(() => _refillIntervalDays = v),
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Special Instructions (optional)',
                hint: 'e.g. Take with food',
                controller: _instructionsCtrl,
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              MediaAttachmentWidget(
                controller: _mediaController,
                label: 'Prescription Attachments (optional)',
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: const TextStyle(color: kError, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              AppButton(
                label: 'Add Medication',
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

// ── Pharmacy Picker Widget ─────────────────────────────────────────────────────
class _PharmacyPicker extends ConsumerWidget {
  final Pharmacy? selected;
  final ValueChanged<Pharmacy?> onChanged;

  const _PharmacyPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pharmaciesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pickup Pharmacy (optional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the pharmacy where you collect this medication',
          style: TextStyle(fontSize: 11, color: kSubtext),
        ),
        const SizedBox(height: 8),
        if (state.isLoading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else
          DropdownButtonFormField<String>(
            value: selected?.id,
            hint: const Text('Select pharmacy'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.local_pharmacy_outlined, color: kSubtext),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...state.pharmacies.map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 14)),
                      if (p.address != null)
                        Text(p.address!,
                            style: const TextStyle(
                                fontSize: 11, color: kSubtext)),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (id) {
              if (id == null) {
                onChanged(null);
              } else {
                onChanged(state.pharmacies.firstWhere((p) => p.id == id));
              }
            },
          ),
      ],
    );
  }
}

// ── Refill Interval Picker Widget ─────────────────────────────────────────────
class _RefillIntervalPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _RefillIntervalPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = <String, int?>{
      'No refill reminder': null,
      'Every 30 days (1 month)': 30,
      'Every 60 days (2 months)': 60,
      'Every 90 days (3 months)': 90,
      'Every 180 days (6 months)': 180,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Refill Reminder',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
        ),
        const SizedBox(height: 4),
        const Text(
          'Get notified before your medication runs out',
          style: TextStyle(fontSize: 11, color: kSubtext),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: value,
          hint: const Text('Select refill cycle'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.refresh_outlined, color: kSubtext),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: options.entries
              .map((e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(e.key),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
