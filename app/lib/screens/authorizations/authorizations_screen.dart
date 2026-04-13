import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/authorization_request.dart';
import '../../providers/authorizations_provider.dart';
import '../../widgets/common/loading_shimmer.dart';

class AuthorizationsScreen extends ConsumerStatefulWidget {
  const AuthorizationsScreen({super.key});

  @override
  ConsumerState<AuthorizationsScreen> createState() =>
      _AuthorizationsScreenState();
}

class _AuthorizationsScreenState extends ConsumerState<AuthorizationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authorizationsProvider.notifier).fetchMyRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authorizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Authorization Requests'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(authorizationsProvider.notifier).fetchMyRequests(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/authorizations/request'),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
        backgroundColor: kPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(authorizationsProvider.notifier).fetchMyRequests(),
        child: state.isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingListCard(count: 4),
              )
            : state.requests.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _AuthCard(request: state.requests[i]),
                  ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 64, color: kSubtext.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'No Authorization Requests',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kSubtext),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit a request to get Sanlam approval\nbefore picking up medication or\nundergoing a procedure.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kSubtext),
            ),
          ],
        ),
      );
}

class _AuthCard extends ConsumerWidget {
  final AuthorizationRequest request;
  const _AuthCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusInfo = _statusInfo(request.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kBorder.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.requestTypeLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$1.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusInfo.$1.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusInfo.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusInfo.$1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Provider
            if (request.providerName != null)
              _InfoRow(
                icon: request.providerType == 'pharmacy'
                    ? Icons.local_pharmacy_outlined
                    : Icons.local_hospital_outlined,
                text: request.providerName!,
              ),

            // Medication name
            if (request.medicationName != null)
              _InfoRow(
                  icon: Icons.medication_outlined,
                  text: request.medicationName!),

            // Scheduled date
            if (request.scheduledDate != null)
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('d MMM yyyy').format(request.scheduledDate!),
              ),

            // Submitted date
            _InfoRow(
              icon: Icons.schedule_outlined,
              text:
                  'Submitted ${DateFormat('d MMM yyyy').format(request.createdAt)}',
              subtle: true,
            ),

            // Notes
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSurfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.notes!,
                  style:
                      const TextStyle(fontSize: 12, color: kSubtext),
                ),
              ),
            ],

            // Admin comments (shown when approved/rejected)
            if (request.adminComments != null &&
                request.adminComments!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (request.status == AuthRequestStatus.approved
                          ? kSuccess
                          : kError)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (request.status == AuthRequestStatus.approved
                            ? kSuccess
                            : kError)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: request.status == AuthRequestStatus.approved
                          ? kSuccess
                          : kError,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.adminComments!,
                        style: TextStyle(
                          fontSize: 12,
                          color: request.status == AuthRequestStatus.approved
                              ? kSuccess
                              : kError,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancel button (only for pending)
            if (request.status == AuthRequestStatus.pending) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: kBorder),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: const Icon(Icons.cancel_outlined,
                    size: 15, color: kError),
                label: const Text(
                  'Cancel Request',
                  style: TextStyle(
                      color: kError,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text(
            'Are you sure you want to cancel this authorization request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Yes, Cancel', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(authorizationsProvider.notifier)
          .cancelRequest(request.id);
    }
  }

  (Color, String) _statusInfo(AuthRequestStatus status) {
    switch (status) {
      case AuthRequestStatus.approved:
        return (kSuccess, 'Approved');
      case AuthRequestStatus.rejected:
        return (kError, 'Rejected');
      case AuthRequestStatus.cancelled:
        return (kSubtext, 'Cancelled');
      default:
        return (kWarning, 'Pending Review');
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool subtle;
  const _InfoRow(
      {required this.icon, required this.text, this.subtle = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 13, color: subtle ? kSubtext.withValues(alpha: 0.6) : kSubtext),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 12,
                    color: subtle
                        ? kSubtext.withValues(alpha: 0.7)
                        : kSubtext),
              ),
            ),
          ],
        ),
      );
}
