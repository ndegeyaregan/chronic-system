import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';

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
            _statusCard(appt),
            const SizedBox(height: 16),
            _detailsCard(appt),
            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _notesCard(appt.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(Appointment a) {
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
                style: const TextStyle(color: kSubtext, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(Appointment a) {
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
          const Text(
            'Appointment Details',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: kText),
          ),
          const SizedBox(height: 16),
          _row(Icons.local_hospital_outlined, 'Hospital', a.hospitalName),
          if (a.hospitalCity != null)
            _row(Icons.location_on_outlined, 'Location', a.hospitalCity!),
          _row(Icons.medical_services_outlined, 'Condition', a.condition),
          _row(Icons.calendar_today_outlined, 'Date',
              DateFormat('dd MMMM yyyy').format(a.appointmentDate)),
          _row(Icons.schedule_outlined, 'Time', a.preferredTime),
          _row(Icons.description_outlined, 'Reason', a.reason),
        ],
      ),
    );
  }

  Widget _notesCard(String notes) {
    return Container(
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
            'Notes',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: kText),
          ),
          const SizedBox(height: 8),
          Text(notes, style: const TextStyle(fontSize: 13, color: kText)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
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
                      const TextStyle(fontSize: 11, color: kSubtext)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kText)),
            ],
          ),
        ],
      ),
    );
  }
}
