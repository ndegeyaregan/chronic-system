import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/visit.dart';
import 'claim_status_chip.dart';
import '../../core/app_colors.dart';

class VisitTile extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;

  const VisitTile({super.key, required this.visit, required this.onTap});

  String _formatDate(String raw) {
    final dt = parseFlexibleDate(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.institution,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.c.text,
                    ),
                  ),
                ),
                ClaimStatusChip(status: visit.claimStatus),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: context.c.subtext),
                const SizedBox(width: 4),
                Text(
                  _formatDate(visit.treatmentDate),
                  style: TextStyle(fontSize: 12, color: context.c.subtext),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(kRadiusFull),
                  ),
                  child: Text(
                    visit.treatmentType,
                    style: const TextStyle(fontSize: 11, color: kPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Claim: ${visit.claimNo}',
                  style: TextStyle(fontSize: 11, color: context.c.subtext),
                ),
                Money(
                  amount: visit.totalAmount,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
