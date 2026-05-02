import 'package:flutter/material.dart';
import '../../core/constants.dart';

class ClaimStatusChip extends StatelessWidget {
  final String status;
  const ClaimStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isCheckedOut = status.toLowerCase() == 'checkedout';
    final color = isCheckedOut ? kSuccess : kAccentAmber;
    final label = isCheckedOut ? 'Checked Out' : 'Pending';
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
