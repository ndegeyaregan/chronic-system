import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../services/api_service.dart';

final cardReprintHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await dio.get('/card-reprints/mine');
  return List<Map<String, dynamic>>.from(res.data as List);
});

class CardReprintHistoryScreen extends ConsumerWidget {
  const CardReprintHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cardReprintHistoryProvider);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'My Reprint Requests',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cardReprintHistoryProvider);
          await ref.read(cardReprintHistoryProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
                  Icon(Icons.credit_card_outlined,
                      size: 56, color: Colors.black26),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No reprint requests yet',
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
              itemBuilder: (_, i) => _ReprintCard(row: rows[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ReprintCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ReprintCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final name = (row['target_member_name'] ?? '').toString();
    final no = (row['target_member_no'] ?? '').toString();
    final relation = (row['target_relation'] ?? '').toString();
    final reason = (row['reason'] ?? '').toString();
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final amount = row['amount'];
    final currency = (row['currency'] ?? 'UGX').toString();

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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.credit_card, color: kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '$relation • $no',
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (createdAt != null) ...[
                      const Icon(Icons.event,
                          size: 12, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a').format(createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      amount != null
                          ? '$currency ${(amount is num ? amount : num.tryParse(amount.toString()) ?? 0).toStringAsFixed(0)}'
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason: $reason',
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
