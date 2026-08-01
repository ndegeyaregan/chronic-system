import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';
import '../../models/hospital.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_input.dart';
import '../../core/app_colors.dart';
import '../../models/benefit.dart';
import '../../services/sanlam_api_service.dart';

enum _TmrCheckStatus { idle, loading, ok, insufficient, error }

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
  final bool skipCondition;
  const BookAppointmentScreen({super.key, this.skipCondition = false});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState
    extends ConsumerState<BookAppointmentScreen> {
  late int _step;
  String? _selectedCondition;
  Hospital? _selectedHospital;
  DateTime? _selectedDate;
  String _preferredTime = '09:00';
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _otherConditionCtrl = TextEditingController();
  bool _otherSelected = false;

  // TMR telehealth: outpatient benefit check state
  _TmrCheckStatus _tmrCheckStatus = _TmrCheckStatus.idle;
  double? _tmrOutpatientBalance;
  String? _tmrCheckError;

  final _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.skipCondition) {
      _step = 1;
      _selectedCondition = 'General Consultation';
    } else {
      _step = 0;
    }
    ref.read(appointmentsProvider.notifier).fetchHospitals();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    _otherConditionCtrl.dispose();
    super.dispose();
  }

  /// Advance stepper and trigger TMR benefit check when entering confirm step.
  void _advanceStep() {
    setState(() => _step++);
    if (_step == 4 && (_selectedHospital?.isTmr ?? false)) {
      _checkTmrBenefits();
    }
  }

  /// Calls Sanlam's GetMemberPlanBenefit to verify outpatient balance.
  /// Only runs when TMR is the selected hospital.
  Future<void> _checkTmrBenefits() async {
    setState(() {
      _tmrCheckStatus = _TmrCheckStatus.loading;
      _tmrCheckError = null;
    });
    try {
      final member = ref.read(authProvider).member!;
      final data = await sanlamApi.getMemberPlanBenefit(member.memberNumber);
      final benefit = Benefit.fromMyJson(data, member);
      setState(() {
        _tmrOutpatientBalance = benefit.outPatient;
        _tmrCheckStatus = benefit.outPatient > 0
            ? _TmrCheckStatus.ok
            : _TmrCheckStatus.insufficient;
      });
    } catch (e) {
      setState(() {
        _tmrCheckStatus = _TmrCheckStatus.error;
        _tmrCheckError = 'Could not verify benefits. Please check your connection and try again.';
      });
    }
  }

  /// True if the hospital treats the selected condition (name-based match).
  bool _matchesCondition(Hospital h) {
    if (_selectedCondition == null) return false;
    final cond = _selectedCondition!.toLowerCase();
    return h.conditionNames.any((n) {
          final nl = n.toLowerCase();
          return nl.contains(cond) || cond.contains(nl);
        }) ||
        h.specialties.any((s) {
          final sl = s.toLowerCase();
          return sl.contains(cond) || cond.contains(sl);
        });
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
    final payload = <String, dynamic>{
      'hospital_id': _selectedHospital!.id,
      'hospital_name': _selectedHospital!.name,
      'hospital_city': _selectedHospital!.city,
      'condition': _selectedCondition,
      'appointment_date': _selectedDate!.toIso8601String(),
      'preferred_time': _preferredTime,
      'reason': _reasonCtrl.text.trim(),
    };

    // TMR: include benefit verification result so backend skips re-check
    if (_selectedHospital!.isTmr) {
      payload['sanlam_verified'] = true;
      payload['outpatient_balance'] = _tmrOutpatientBalance ?? 0;
    }

    final success =
        await ref.read(appointmentsProvider.notifier).bookAppointment(payload);
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

    // Check if the hospital confirmed it directly
    final latestAppt =
        ref.read(appointmentsProvider).appointments.firstOrNull;
    final isInstant = latestAppt?.status == AppointmentStatus.confirmed;

    final dateLabel = _selectedDate != null
        ? DateFormat('d MMM yyyy').format(_selectedDate!)
        : 'the scheduled date';

    NotificationService.show(
      id: 300,
      title: isInstant ? '✅ Appointment Confirmed' : '📅 Appointment Submitted',
      body: isInstant
          ? 'Your appointment on $dateLabel has been confirmed by ${_selectedHospital!.name}.'
          : 'Your appointment on $dateLabel has been submitted. Admin will review and confirm.',
    );

    await ref.read(appointmentsProvider.notifier).fetchAppointments();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isInstant
            ? 'Appointment confirmed! ${_selectedHospital!.name} has been notified.'
            : 'Appointment request submitted! Admin will review and confirm.'),
        backgroundColor: kSuccess,
      ),
    );
    context.go(routeAppointments);
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
          // Hospital step gets its own sticky search + scrollable list layout
          if (_step == 1)
            Expanded(child: _buildHospitalStep(context, apptState))
          else
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
    final allSteps = ['Condition', 'Hospital', 'Date & Time', 'Reason', 'Confirm'];
    // For non-chronic, hide the Condition step — internal indices still map 1-4
    final steps = widget.skipCondition ? allSteps.sublist(1) : allSteps;
    final displayOffset = widget.skipCondition ? 1 : 0;

    return Container(
      color: context.c.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final internalIndex = i + displayOffset;
          final isActive = internalIndex == _step;
          final isDone = internalIndex < _step;
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
                      color: internalIndex < _step ? kSuccess : context.c.border,
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
        GestureDetector(
          onTap: () => setState(() {
            _otherSelected = true;
            _selectedCondition = _otherConditionCtrl.text.trim().isEmpty
                ? null
                : _otherConditionCtrl.text.trim();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  _otherSelected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
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
                      _selectedCondition =
                          v.trim().isEmpty ? null : v.trim();
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

    // Condition-matching + direct-booking hospitals surface first
    final sorted = [...hospitals]..sort((a, b) {
        final aScore =
            (_matchesCondition(a) ? 2 : 0) + (a.hasDirectBooking ? 1 : 0);
        final bScore =
            (_matchesCondition(b) ? 2 : 0) + (b.hasDirectBooking ? 1 : 0);
        return bScore.compareTo(aScore);
      });

    // Sticky search bar + independently scrolling list so the search
    // field stays visible regardless of how far down the user scrolls.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Pinned search bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: AppInput(
            label: 'Search hospital or clinic',
            hint: 'e.g. Heart Institute, Cancer Institute...',
            controller: _searchCtrl,
            prefixIcon: Icon(Icons.search, color: context.c.subtext),
            onChanged: (v) {
              ref.read(appointmentsProvider.notifier).fetchHospitals(
                  search: v.trim().isEmpty ? null : v.trim());
            },
          ),
        ),
        if (_selectedCondition != null && !widget.skipCondition)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 14, color: context.c.subtext),
                const SizedBox(width: 6),
                Text(
                  'Filtered for: $_selectedCondition',
                  style: TextStyle(fontSize: 12, color: context.c.subtext),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // ── Scrollable hospital list ───────────────────────────────────
        if (sorted.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No hospitals found. Try a different search.',
                style: TextStyle(color: context.c.subtext),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) => _hospitalTile(ctx, sorted[i]),
            ),
          ),
      ],
    );
  }

  Widget _hospitalTile(BuildContext context, Hospital h) {
    final isSelected = _selectedHospital?.id == h.id;
    final matches = _matchesCondition(h);

    return GestureDetector(
      onTap: () => setState(() => _selectedHospital = h),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimary : context.c.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + checkmark
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    h.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.c.text,
                    ),
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check_circle, color: kPrimary, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              [h.city, h.province, if (h.type != null && h.type!.isNotEmpty) h.type!]
                  .join(' · '),
              style: TextStyle(fontSize: 12, color: context.c.subtext),
            ),
            // Badges
            if (h.isTmr || h.hasDirectBooking || matches) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (h.isTmr)
                    _infoBadge(
                      context,
                      Icons.video_call_outlined,
                      'Telehealth',
                      kInfo,
                    ),
                  if (h.hasDirectBooking && !h.isTmr)
                    _infoBadge(
                      context,
                      Icons.bolt,
                      'Instant Booking',
                      kSuccess,
                    ),
                  if (matches && _selectedCondition != null)
                    _infoBadge(
                      context,
                      Icons.check_circle_outline,
                      'Treats $_selectedCondition',
                      kPrimary,
                    ),
                ],
              ),
            ],
            // Specialties chips
            if (h.specialties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: h.specialties.take(4).map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.c.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s,
                      style:
                          TextStyle(fontSize: 10, color: context.c.subtext),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Phone & working hours
            if (h.phone != null || h.workingHours != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (h.phone != null) ...[
                    Icon(Icons.phone_outlined,
                        size: 12, color: context.c.subtext),
                    const SizedBox(width: 4),
                    Text(
                      h.phone!,
                      style:
                          TextStyle(fontSize: 11, color: context.c.subtext),
                    ),
                  ],
                  if (h.phone != null && h.workingHours != null)
                    const SizedBox(width: 12),
                  if (h.workingHours != null) ...[
                    Icon(Icons.schedule_outlined,
                        size: 12, color: context.c.subtext),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        h.workingHours!,
                        style:
                            TextStyle(fontSize: 11, color: context.c.subtext),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
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
              color: context.c.cardBg,
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
                    color: _selectedDate == null
                        ? context.c.subtext
                        : context.c.text,
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
                      color: _preferredTime == t ? kPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _preferredTime == t ? kPrimary : context.c.border,
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
    final isTmr = _selectedHospital?.isTmr ?? false;
    final isInstant = isTmr || (_selectedHospital?.hasDirectBooking ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Appointment summary ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.c.cardBg,
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
              _summaryRow(context, 'Location', _selectedHospital?.city ?? '—'),
              if (_selectedHospital?.address != null)
                _summaryRow(context, 'Address', _selectedHospital!.address!),
              if (_selectedHospital?.phone != null)
                _summaryRow(context, 'Phone', _selectedHospital!.phone!),
              _summaryRow(
                  context,
                  'Date',
                  _selectedDate != null
                      ? DateFormat('dd MMMM yyyy').format(_selectedDate!)
                      : '—'),
              _summaryRow(context, 'Time', _preferredTime),
              _summaryRow(context, 'Reason', _reasonCtrl.text),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── TMR outpatient benefit check ─────────────────────────────────
        if (isTmr) _buildTmrBenefitCheck(context),

        // ── Booking mode notice ──────────────────────────────────────────
        if (!isTmr) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (isInstant ? kSuccess : kWarning).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (isInstant ? kSuccess : kWarning)
                      .withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isInstant ? Icons.bolt_outlined : Icons.info_outline,
                  color: isInstant ? kSuccess : kWarning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isInstant
                        ? 'This hospital supports instant booking. Your appointment will be confirmed immediately once submitted.'
                        : 'Your appointment request will be reviewed and confirmed by the Sanlam admin team. You\'ll receive a notification once confirmed.',
                    style: TextStyle(fontSize: 12, color: context.c.text),
                  ),
                ),
              ],
            ),
          ),
        ],

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

  Widget _buildTmrBenefitCheck(BuildContext context) {
    const purple = kInfo;

    Widget card({
      required Color color,
      required IconData icon,
      required String title,
      required String body,
      Widget? trailing,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(body,
                      style:
                          TextStyle(fontSize: 12, color: context.c.text)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    switch (_tmrCheckStatus) {
      case _TmrCheckStatus.loading:
        return card(
          color: purple,
          icon: Icons.verified_user_outlined,
          title: 'Checking your outpatient benefit...',
          body: 'We are verifying your Sanlam outpatient balance before connecting you to TMR.',
          trailing: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case _TmrCheckStatus.ok:
        final balance = _tmrOutpatientBalance ?? 0;
        final fmt = NumberFormat('#,###', 'en_US');
        return card(
          color: kSuccess,
          icon: Icons.check_circle_outline,
          title: 'Outpatient balance confirmed',
          body: 'You have UGX ${fmt.format(balance.toInt())} available. '
              'TMR will not re-verify your insurance — your consultation can proceed immediately.',
        );

      case _TmrCheckStatus.insufficient:
        return card(
          color: kError,
          icon: Icons.money_off_outlined,
          title: 'Insufficient outpatient balance',
          body: 'Your outpatient benefit pool is exhausted for this year. '
              'You cannot book a TMR telehealth appointment until your plan is renewed or topped up. '
              'Please contact Sanlam for assistance.',
        );

      case _TmrCheckStatus.error:
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWarning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kWarning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: kWarning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Could not verify benefits',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: kWarning)),
                    const SizedBox(height: 3),
                    Text(_tmrCheckError ?? 'Unknown error',
                        style: TextStyle(fontSize: 12, color: context.c.text)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _checkTmrBenefits,
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case _TmrCheckStatus.idle:
        return const SizedBox();
    }
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.c.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons(BuildContext context, AppointmentsState apptState) {
    // For TMR confirm step: block submission if benefit check hasn't passed
    final tmrBlocked = _step == 4 &&
        (_selectedHospital?.isTmr ?? false) &&
        _tmrCheckStatus != _TmrCheckStatus.ok;

    final canNext = !tmrBlocked &&
        switch (_step) {
          0 => _selectedCondition != null,
          1 => _selectedHospital != null,
          2 => _selectedDate != null,
          3 => _reasonCtrl.text.trim().isNotEmpty,
          _ => true,
        };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.c.cardBg,
        border: Border(top: BorderSide(color: context.c.border)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  final firstStep = widget.skipCondition ? 1 : 0;
                  if (_step <= firstStep) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _step--);
                  }
                },
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
                      ? _advanceStep
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
