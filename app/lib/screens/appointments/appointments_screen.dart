import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';
import '../../widgets/common/loading_shimmer.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() =>
      _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(routeBookAppointment),
        icon: const Icon(Icons.add),
        label: const Text('Book Appointment'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AppointmentsList(
            appointments: state.upcoming,
            isLoading: state.isLoading,
            isPast: false,
            ref: ref,
          ),
          _AppointmentsList(
            appointments: state.past,
            isLoading: state.isLoading,
            isPast: true,
            ref: ref,
          ),
        ],
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  final List<Appointment> appointments;
  final bool isLoading;
  final bool isPast;
  final WidgetRef ref;

  const _AppointmentsList({
    required this.appointments,
    required this.isLoading,
    required this.isPast,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingListCard(count: 4),
      );
    }

    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Color(0xFFCBD5E1), size: 64),
            const SizedBox(height: 16),
            Text(
              isPast
                  ? 'No past appointments'
                  : 'No upcoming appointments',
              style: const TextStyle(
                  color: kSubtext, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (!isPast)
              const Text(
                'Book an appointment to see your care team.',
                style: TextStyle(color: kSubtext, fontSize: 13),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () =>
          ref.read(appointmentsProvider.notifier).fetchAppointments(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: appointments.length,
        itemBuilder: (context, i) =>
            _AppointmentCard(appointment: appointments[i], ref: ref),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final WidgetRef ref;

  const _AppointmentCard({required this.appointment, required this.ref});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/appointments/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(a.appointmentDate),
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(a.appointmentDate),
                          style: const TextStyle(
                              color: kPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.hospitalName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${a.condition} · ${a.preferredTime}',
                          style: const TextStyle(fontSize: 12, color: kSubtext),
                        ),
                        if (a.hospitalCity != null)
                          Text(
                            a.hospitalCity!,
                            style: const TextStyle(fontSize: 12, color: kSubtext),
                          ),
                        const SizedBox(height: 8),
                        _statusBadge(a.status),
                        if (a.missedReason != null && a.missedReason!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.comment_outlined, size: 12, color: kSubtext),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  a.missedReason!,
                                  style: const TextStyle(fontSize: 11, color: kSubtext, fontStyle: FontStyle.italic),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kSubtext, size: 20),
                ],
              ),
              // Confirmation buttons for past appointments
              if (a.needsConfirmation) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Did you attend this appointment?',
                  style: TextStyle(fontSize: 12, color: kSubtext, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmAttended(context, a.id),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('I Attended', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSuccess,
                          side: const BorderSide(color: kSuccess),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markMissed(context, a.id),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('I Missed It', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kError,
                          side: const BorderSide(color: kError),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAttended(BuildContext context, String id) async {
    final ok = await ref
        .read(appointmentsProvider.notifier)
        .confirmAttended(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Marked as attended' : 'Failed to update'),
        backgroundColor: ok ? kSuccess : kError,
      ));
    }
  }

  void _markMissed(BuildContext context, String id) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason for Missing'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional: explain why you missed this appointment',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null) return; // user cancelled
    final ok = await ref
        .read(appointmentsProvider.notifier)
        .markMissed(id, reason: reason.isEmpty ? null : reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '⚠️ Marked as missed' : 'Failed to update'),
        backgroundColor: ok ? kWarning : kError,
      ));
    }
  }

  Widget _statusBadge(AppointmentStatus status) {
    Color color;
    String label;
    switch (status) {
      case AppointmentStatus.confirmed:
        color = kSuccess;
        label = 'Confirmed';
        break;
      case AppointmentStatus.cancelled:
        color = kError;
        label = 'Cancelled';
        break;
      case AppointmentStatus.completed:
        color = kPrimary;
        label = 'Attended';
        break;
      case AppointmentStatus.missed:
        color = kWarning;
        label = 'Missed';
        break;
      default:
        color = const Color(0xFFF59E0B);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
