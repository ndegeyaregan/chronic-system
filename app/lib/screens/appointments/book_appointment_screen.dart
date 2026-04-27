import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../models/hospital.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_input.dart';

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCondition == null ||
        _selectedHospital == null ||
        _selectedDate == null ||
        _reasonCtrl.text.trim().isEmpty) {
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
    if (success && mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).member;
    final apptState = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(member, apptState),
            ),
          ),
          _buildNavButtons(apptState),
        ],
      ),
    );
  }

  Widget _buildStepper() {
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
                                  : kBorder,
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
                                        : kSubtext,
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
                          color: isActive ? kPrimary : kSubtext,
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
                      color: i < _step ? kSuccess : kBorder,
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
        return _buildConditionStep(member);
      case 1:
        return _buildHospitalStep(apptState);
      case 2:
        return _buildDateTimeStep();
      case 3:
        return _buildReasonStep();
      case 4:
        return _buildConfirmStep(apptState);
      default:
        return const SizedBox();
    }
  }

  Widget _buildConditionStep(member) {
    final conditions = member?.conditions as List<String>? ?? [];
    if (conditions.isEmpty) {
      return const Center(
        child: Text(
          'No conditions found. Please contact support.',
          style: TextStyle(color: kSubtext),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select the condition related to this appointment:',
          style: TextStyle(fontSize: 14, color: kSubtext),
        ),
        const SizedBox(height: 16),
        ...conditions.map(
          (c) => GestureDetector(
            onTap: () => setState(() => _selectedCondition = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedCondition == c
                    ? kPrimary.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCondition == c ? kPrimary : kBorder,
                  width: _selectedCondition == c ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital_outlined,
                    color: _selectedCondition == c ? kPrimary : kSubtext,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedCondition == c ? kPrimary : kText,
                      ),
                    ),
                  ),
                  if (_selectedCondition == c)
                    const Icon(Icons.check_circle, color: kPrimary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalStep(AppointmentsState apptState) {
    final hospitals = apptState.hospitals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: 'Search hospital or clinic',
          hint: 'e.g. Heart Institute, Cancer Institute...',
          controller: _cityCtrl,
          prefixIcon: const Icon(Icons.search, color: kSubtext),
          onChanged: (v) {
            ref
                .read(appointmentsProvider.notifier)
                .fetchHospitals(search: v.trim().isEmpty ? null : v.trim());
          },
        ),
        const SizedBox(height: 16),
        if (hospitals.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hospitals found. Try a different search.',
                style: TextStyle(color: kSubtext),
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
                    color: _selectedHospital?.id == h.id ? kPrimary : kBorder,
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
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, color: kText),
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
                      style: const TextStyle(fontSize: 12, color: kSubtext),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select preferred appointment date:',
          style: TextStyle(fontSize: 14, color: kSubtext),
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
                  color: _selectedDate != null ? kPrimary : kBorder),
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
                    color: _selectedDate == null ? kSubtext : kText,
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
        const Text(
          'Preferred time:',
          style: TextStyle(fontSize: 14, color: kSubtext),
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
                        color: _preferredTime == t ? kPrimary : kBorder,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: _preferredTime == t
                            ? Colors.white
                            : kText,
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

  Widget _buildReasonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Describe the reason for your visit:',
          style: TextStyle(fontSize: 14, color: kSubtext),
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

  Widget _buildConfirmStep(AppointmentsState apptState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appointment Summary',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kText),
              ),
              const SizedBox(height: 16),
              _summaryRow('Condition', _selectedCondition ?? '—'),
              _summaryRow('Hospital', _selectedHospital?.name ?? '—'),
              _summaryRow(
                  'Location', _selectedHospital?.city ?? '—'),
              _summaryRow(
                  'Date',
                  _selectedDate != null
                      ? DateFormat('dd MMMM yyyy')
                          .format(_selectedDate!)
                      : '—'),
              _summaryRow('Time', _preferredTime),
              _summaryRow('Reason', _reasonCtrl.text),
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
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: kWarning, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your appointment request will be reviewed and confirmed by the Sanlam admin team. You\'ll receive a notification once confirmed.',
                  style: TextStyle(fontSize: 12, color: kText),
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

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kSubtext),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: kText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons(AppointmentsState apptState) {
    final canNext = switch (_step) {
      0 => _selectedCondition != null,
      1 => _selectedHospital != null,
      2 => _selectedDate != null,
      3 => _reasonCtrl.text.trim().isNotEmpty,
      _ => true,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Back'),
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
