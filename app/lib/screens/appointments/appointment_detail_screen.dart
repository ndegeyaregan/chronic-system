import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';
import '../../core/app_colors.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  final String id;

  const AppointmentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appointmentsProvider);
    final appt = state.appointments.where((a) => a.id == id).firstOrNull;

    if (appt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointment')),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        actions: [
          if (appt.status == AppointmentStatus.pending ||
              appt.status == AppointmentStatus.confirmed)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Cancel Appointment'),
                    content: const Text(
                        'Are you sure you want to cancel this appointment?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kError),
                        child: const Text('Cancel Appointment'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref
                      .read(appointmentsProvider.notifier)
                      .cancelAppointment(id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(context, appt),
            const SizedBox(height: 16),
            _hospitalCard(context, appt),
            const SizedBox(height: 16),
            _appointmentCard(context, appt),
            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _notesCard(context, appt.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context, Appointment a) {
    Color color;
    IconData icon;
    String title;
    String subtitle;

    switch (a.status) {
      case AppointmentStatus.confirmed:
        color = kSuccess;
        icon = Icons.check_circle_outline;
        title = a.isDirectBooked
            ? 'Confirmed by Hospital'
            : 'Appointment Confirmed';
        subtitle = a.confirmedDate != null
            ? 'Confirmed for ${DateFormat('EEEE, dd MMMM yyyy').format(a.confirmedDate!)}'
            : DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
        break;
      case AppointmentStatus.cancelled:
        color = kError;
        icon = Icons.cancel_outlined;
        title = 'Appointment Cancelled';
        subtitle = DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
        break;
      case AppointmentStatus.completed:
        color = kPrimary;
        icon = Icons.task_alt_outlined;
        title = 'Appointment Completed';
        subtitle = DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
        break;
      case AppointmentStatus.missed:
        color = kWarning;
        icon = Icons.event_busy_outlined;
        title = 'Appointment Missed';
        subtitle = DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
        break;
      default:
        color = kWarning;
        icon = Icons.pending_outlined;
        title = 'Awaiting Confirmation';
        subtitle = DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 15),
                      ),
                    ),
                    if (a.isDirectBooked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: kSuccess.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, size: 10, color: kSuccess),
                            const SizedBox(width: 3),
                            Text(
                              'Direct',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: kSuccess,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: context.c.subtext, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalCard(BuildContext context, Appointment a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hospital / Clinic',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.c.text),
          ),
          const SizedBox(height: 12),
          _row(context, Icons.local_hospital_outlined, 'Name', a.hospitalName),
          if (a.hospitalCity != null)
            _row(context, Icons.location_city_outlined, 'City', a.hospitalCity!),
          if (a.hospitalAddress != null)
            _row(context, Icons.location_on_outlined, 'Address', a.hospitalAddress!),
          if (a.hospitalPhone != null)
            _row(context, Icons.phone_outlined, 'Phone', a.hospitalPhone!),
        ],
      ),
    );
  }

  Widget _appointmentCard(BuildContext context, Appointment a) {
    final effectiveDate =
        a.confirmedDate ?? a.appointmentDate;
    final effectiveTime =
        (a.confirmedTime != null && a.confirmedTime!.isNotEmpty)
            ? a.confirmedTime!
            : a.preferredTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment Details',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.c.text),
          ),
          const SizedBox(height: 12),
          _row(context, Icons.medical_services_outlined, 'Condition', a.condition),
          _row(
            context,
            Icons.calendar_today_outlined,
            a.confirmedDate != null ? 'Confirmed Date' : 'Requested Date',
            DateFormat('dd MMMM yyyy').format(effectiveDate),
          ),
          _row(context, Icons.schedule_outlined,
              a.confirmedTime != null ? 'Confirmed Time' : 'Preferred Time',
              effectiveTime),
          _row(context, Icons.description_outlined, 'Reason', a.reason),
          if (a.missedReason != null && a.missedReason!.isNotEmpty)
            _row(context, Icons.comment_outlined, 'Missed Reason', a.missedReason!),
        ],
      ),
    );
  }

  Widget _notesCard(BuildContext context, String notes) {
    return Container(
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
            'Notes from Admin',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.c.text),
          ),
          const SizedBox(height: 8),
          Text(notes, style: TextStyle(fontSize: 13, color: context.c.text)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kPrimary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: context.c.subtext)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.c.text)),
            ],
          ),
        ],
      ),
    );
  }
}
