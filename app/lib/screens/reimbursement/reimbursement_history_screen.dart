import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../services/api_service.dart';

final reimbursementHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await dio.get('/reimbursements/mine');
  return List<Map<String, dynamic>>.from(res.data as List);
});

class ReimbursementHistoryScreen extends ConsumerWidget {
  const ReimbursementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reimbursementHistoryProvider);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'My Reimbursements',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reimbursementHistoryProvider);
          await ref.read(reimbursementHistoryProvider.future);
        },
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is DioException ? extractErrorMessage(e) : '$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.black26),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No reimbursement requests yet',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ReimbCard(row: rows[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ReimbCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ReimbCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final hospital = (row['hospital_name'] ?? '').toString();
    final reason = (row['reason'] ?? '').toString();
    final amount = row['amount'];
    final paidAmount = row['paid_amount'];
    final currency = (row['currency'] ?? 'UGX').toString();
    final status = (row['status'] ?? 'pending').toString();
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final paidAt = DateTime.tryParse(row['paid_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hospital,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(
                amount != null
                    ? '$currency ${_fmtNum(amount)}'
                    : 'Amount: not specified',
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  DateFormat('d MMM yyyy').format(createdAt),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
          if (status == 'paid' && paidAmount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Paid $currency ${_fmtNum(paidAmount)}'
                      '${paidAt != null ? ' on ${DateFormat('d MMM yyyy').format(paidAt)}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtNum(dynamic v) {
    final n = v is num ? v : num.tryParse(v.toString()) ?? 0;
    return NumberFormat('#,###').format(n);
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      'paid' => (Colors.green, 'Paid', Icons.check_circle),
      'rejected' => (kError, 'Rejected', Icons.cancel),
      'under_review' => (
        const Color(0xFF2563EB),
        'Under Review',
        Icons.hourglass_top
      ),
      _ => (const Color(0xFFF59E0B), 'Pending', Icons.pending_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
