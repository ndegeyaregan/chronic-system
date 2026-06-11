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
        appBar: AppBar(title: Text('Appointment')),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Appointment Details'),
        actions: [
          if (appt.status == AppointmentStatus.pending ||
              appt.status == AppointmentStatus.confirmed)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Cancel Appointment'),
                    content: Text(
                        'Are you sure you want to cancel this appointment?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kError),
                        child: Text('Cancel Appointment'),
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
              child: Text(
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
            _detailsCard(context, appt),
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
    switch (a.status) {
      case AppointmentStatus.confirmed:
        color = kSuccess;
        icon = Icons.check_circle_outline;
        title = 'Appointment Confirmed';
        break;
      case AppointmentStatus.cancelled:
        color = kError;
        icon = Icons.cancel_outlined;
        title = 'Appointment Cancelled';
        break;
      case AppointmentStatus.completed:
        color = kPrimary;
        icon = Icons.task_alt_outlined;
        title = 'Appointment Completed';
        break;
      default:
        color = kWarning;
        icon = Icons.pending_outlined;
        title = 'Awaiting Confirmation';
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 15),
              ),
              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate),
                style: TextStyle(color: context.c.subtext, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(BuildContext context, Appointment a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                fontSize: 15, fontWeight: FontWeight.bold, color: context.c.text),
          ),
          const SizedBox(height: 16),
          _row(context, Icons.local_hospital_outlined, 'Hospital', a.hospitalName),
          if (a.hospitalCity != null)
            _row(context, Icons.location_on_outlined, 'Location', a.hospitalCity!),
          _row(context, Icons.medical_services_outlined, 'Condition', a.condition),
          _row(context, Icons.calendar_today_outlined, 'Date',
              DateFormat('dd MMMM yyyy').format(a.appointmentDate)),
          _row(context, Icons.schedule_outlined, 'Time', a.preferredTime),
          _row(context, Icons.description_outlined, 'Reason', a.reason),
        ],
      ),
    );
  }

  Widget _notesCard(BuildContext context, String notes) {
    return Container(
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
            'Notes',
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
                  style:
                      TextStyle(fontSize: 11, color: context.c.subtext)),
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
