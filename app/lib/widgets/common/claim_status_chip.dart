import 'package:flutter/material.dart';
import '../../core/constants.dart';

class ClaimStatusChip extends StatelessWidget {
  final String status;
  const ClaimStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    late final String label;
    late final Color color;
    switch (s) {
      case 'paid':
        label = 'Settled';
        color = kSuccess;
        break;
      case 'reconciled':
        label = 'Reconciled';
        color = kSuccess;
        break;
      case 'processed':
        label = 'Processed';
        color = kSuccess;
        break;
      case 'checkedout':
        label = 'Checked Out';
        color = kSuccess;
        break;
      case 'rejected':
      case 'declined':
        label = 'Rejected';
        color = kError;
        break;
      case 'open':
      case 'pending':
      case 'uncheckedout':
      case '':
        label = 'Pending';
        color = kAccentAmber;
        break;
      default:
        label = 'Pending';
        color = kAccentAmber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
