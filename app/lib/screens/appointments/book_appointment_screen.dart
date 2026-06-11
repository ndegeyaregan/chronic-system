import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../models/hospital.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_input.dart';
import '../../core/app_colors.dart';

/// Catalog of all chronic conditions (read-only public list).
final _allConditionsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final resp = await dio.get('/conditions');
    final list = (resp.data is List)
        ? resp.data as List
        : (resp.data['data'] as List? ?? const []);
    return list
        .map((e) => (e is Map ? (e['name'] ?? '') : e).toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
  } on DioException catch (_) {
    return const <String>[];
  } catch (_) {
    return const <String>[];
  }
});

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState
    extends ConsumerState<BookAppointmentScreen> {
  int _step = 0;
  String? _selectedCondition;
  Hospital? _selectedHospital;
  DateTime? _selectedDate;
  String _preferredTime = '09:00';
  final _reasonCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _otherConditionCtrl = TextEditingController();
  bool _otherSelected = false;

  final _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00',
  ];

  @override
  void initState() {
    super.initState();
    ref.read(appointmentsProvider.notifier).fetchHospitals();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _cityCtrl.dispose();
    _otherConditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final missing = <String>[];
    if (_selectedCondition == null) missing.add('condition');
    if (_selectedHospital == null) missing.add('hospital');
    if (_selectedDate == null) missing.add('date');
    if (_reasonCtrl.text.trim().isEmpty) missing.add('reason');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in: ${missing.join(", ")}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final success =
        await ref.read(appointmentsProvider.notifier).bookAppointment({
      'hospital_id': _selectedHospital!.id,
      'hospital_name': _selectedHospital!.name,
      'hospital_city': _selectedHospital!.city,
      'condition': _selectedCondition,
      'appointment_date': _selectedDate!.toIso8601String(),
      'preferred_time': _preferredTime,
      'reason': _reasonCtrl.text.trim(),
    });
    if (!mounted) return;
    if (!success) {
      final err = ref.read(appointmentsProvider).error ??
          'Could not submit appointment. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    // Show confirmation notification
    final dateLabel = _selectedDate != null
        ? DateFormat('d MMM yyyy').format(_selectedDate!)
        : 'the scheduled date';
    NotificationService.show(
      id: 300,
      title: '📅 Appointment Confirmed',
      body: 'Your appointment on $dateLabel has been submitted. Admin will review and confirm.',
    );
    // Refresh then go to appointments — Upcoming tab
    await ref.read(appointmentsProvider.notifier).fetchAppointments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment request submitted! Admin will review and confirm.'),
          backgroundColor: kSuccess,
        ),
      );
      context.go(routeAppointments);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).member;
    final apptState = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Book Appointment'),
      ),
      body: Column(
        children: [
          _buildStepper(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(member, apptState),
            ),
          ),
          _buildNavButtons(context, apptState),
        ],
      ),
    );
  }

  Widget _buildStepper(BuildContext context) {
    final steps = ['Condition', 'Hospital', 'Date & Time', 'Reason', 'Confirm'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? kSuccess
                              : isActive
                                  ? kPrimary
                                  : context.c.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : context.c.subtext,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: isActive ? kPrimary : context.c.subtext,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: i < _step ? kSuccess : context.c.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(member, AppointmentsState apptState) {
    switch (_step) {
      case 0:
        return _buildConditionStep(context, member);
      case 1:
        return _buildHospitalStep(context, apptState);
      case 2:
        return _buildDateTimeStep(context);
      case 3:
        return _buildReasonStep(context);
      case 4:
        return _buildConfirmStep(context, apptState);
      default:
        return const SizedBox();
    }
  }

  Widget _buildConditionStep(BuildContext context, member) {
    final myConditions = (member?.conditions as List<String>? ?? const <String>[])
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final catalogAsync = ref.watch(_allConditionsProvider);

    Widget conditionTile(String label, {IconData? icon}) {
      final selected = !_otherSelected && _selectedCondition == label;
      return GestureDetector(
        onTap: () => setState(() {
          _otherSelected = false;
          _selectedCondition = label;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kPrimary : context.c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon ?? Icons.local_hospital_outlined,
                color: selected ? kPrimary : context.c.subtext,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? kPrimary : context.c.text,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: kPrimary, size: 20),
            ],
          ),
        ),
      );
    }

    final catalog = catalogAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <String>[],
    );
    // Fallback list so the user always has *something* to pick even if the API
    // is unreachable and they have no chronic conditions registered.
    final fallback = <String>[
      'General Consultation',
      'Hypertension',
      'Diabetes',
      'Asthma',
      'HIV/AIDS',
      'Heart Disease',
      'Kidney Disease',
      'Arthritis',
      'Depression & Anxiety',
    ];
    final extras = (catalog.isNotEmpty ? catalog : fallback)
        .where((c) => !myConditions.contains(c))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select the condition related to this appointment:',
          style: TextStyle(fontSize: 14, color: context.c.subtext),
        ),
        const SizedBox(height: 16),
        if (myConditions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'YOUR REGISTERED CONDITIONS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: context.c.subtext,
              ),
            ),
          ),
          ...myConditions.map((c) => conditionTile(c, icon: Icons.favorite_outline)),
          const SizedBox(height: 10),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            myConditions.isNotEmpty ? 'OTHER CONDITIONS' : 'CHOOSE A CONDITION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: context.c.subtext,
            ),
          ),
        ),
        if (catalogAsync.isLoading && extras.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...extras.map((c) => conditionTile(c)),
        const SizedBox(height: 8),
        // "Other" free-text fallback — never let the user be stuck.
        GestureDetector(
          onTap: () => setState(() {
            _otherSelected = true;
            _selectedCondition =
                _otherConditionCtrl.text.trim().isEmpty ? null : _otherConditionCtrl.text.trim();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _otherSelected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _otherSelected ? kPrimary : context.c.border,
                width: _otherSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_outlined,
                        color: _otherSelected ? kPrimary : context.c.subtext),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Other / not listed',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _otherSelected ? kPrimary : context.c.text,
                        ),
                      ),
                    ),
                    if (_otherSelected)
                      const Icon(Icons.check_circle, color: kPrimary, size: 20),
                  ],
                ),
                if (_otherSelected) ...[
                  const SizedBox(height: 10),
                  AppInput(
                    label: 'Describe the condition',
                    hint: 'e.g. Routine check-up, malaria, prenatal visit…',
                    controller: _otherConditionCtrl,
                    onChanged: (v) => setState(() {
                      _selectedCondition = v.trim().isEmpty ? null : v.trim();
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalStep(BuildContext context, AppointmentsState apptState) {
    final hospitals = apptState.hospitals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: 'Search hospital or clinic',
          hint: 'e.g. Heart Institute, Cancer Institute...',
          controller: _cityCtrl,
          prefixIcon: Icon(Icons.search, color: context.c.subtext),
          onChanged: (v) {
            ref
                .read(appointmentsProvider.notifier)
                .fetchHospitals(search: v.trim().isEmpty ? null : v.trim());
          },
        ),
        const SizedBox(height: 16),
        if (hospitals.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hospitals found. Try a different search.',
                style: TextStyle(color: context.c.subtext),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...hospitals.map(
            (h) => GestureDetector(
              onTap: () => setState(() => _selectedHospital = h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedHospital?.id == h.id
                      ? kPrimary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedHospital?.id == h.id ? kPrimary : context.c.border,
                    width: _selectedHospital?.id == h.id ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: context.c.text),
                          ),
                        ),
                        if (_selectedHospital?.id == h.id)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.check_circle,
                                color: kPrimary, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${h.city}, ${h.province}',
                      style: TextStyle(fontSize: 12, color: context.c.subtext),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select preferred appointment date:',
          style: TextStyle(fontSize: 14, color: context.c.subtext),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 180)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme:
                      const ColorScheme.light(primary: kPrimary),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedDate != null ? kPrimary : context.c.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: kPrimary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDate == null
                      ? 'Select date'
                      : DateFormat('EEEE, dd MMMM yyyy')
                          .format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDate == null ? context.c.subtext : context.c.text,
                    fontWeight: _selectedDate != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Preferred time:',
          style: TextStyle(fontSize: 14, color: context.c.subtext),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots
              .map(
                (t) => GestureDetector(
                  onTap: () => setState(() => _preferredTime = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _preferredTime == t
                          ? kPrimary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _preferredTime == t ? kPrimary : context.c.border,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: _preferredTime == t
                            ? Colors.white
                            : context.c.text,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildReasonStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Describe the reason for your visit:',
          style: TextStyle(fontSize: 14, color: context.c.subtext),
        ),
        const SizedBox(height: 16),
        AppInput(
          label: 'Reason for Visit',
          hint:
              'e.g. Routine diabetes check-up, new symptoms, medication review...',
          controller: _reasonCtrl,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context, AppointmentsState apptState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appointment Summary',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.c.text),
              ),
              const SizedBox(height: 16),
              _summaryRow(context, 'Condition', _selectedCondition ?? '—'),
              _summaryRow(context, 'Hospital', _selectedHospital?.name ?? '—'),
              _summaryRow(context, 
                  'Location', _selectedHospital?.city ?? '—'),
              _summaryRow(context, 
                  'Date',
                  _selectedDate != null
                      ? DateFormat('dd MMMM yyyy')
                          .format(_selectedDate!)
                      : '—'),
              _summaryRow(context, 'Time', _preferredTime),
              _summaryRow(context, 'Reason', _reasonCtrl.text),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kWarning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kWarning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: kWarning, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your appointment request will be reviewed and confirmed by the Sanlam admin team. You\'ll receive a notification once confirmed.',
                  style: TextStyle(fontSize: 12, color: context.c.text),
                ),
              ),
            ],
          ),
        ),
        if (apptState.error != null) ...[
          const SizedBox(height: 12),
          Text(
            apptState.error!,
            style: const TextStyle(color: kError, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: context.c.subtext),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: context.c.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons(BuildContext context, AppointmentsState apptState) {
    final canNext = switch (_step) {
      0 => _selectedCondition != null,
      1 => _selectedHospital != null,
      2 => _selectedDate != null,
      3 => _reasonCtrl.text.trim().isNotEmpty,
      _ => true,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: context.c.border)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: !canNext
                  ? null
                  : _step < 4
                      ? () => setState(() => _step++)
                      : apptState.isSubmitting
                          ? null
                          : _submit,
              child: apptState.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_step < 4 ? 'Continue' : 'Confirm Booking'),
            ),
          ),
        ],
      ),
    );
  }
}
