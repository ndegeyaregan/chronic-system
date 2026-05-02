import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/dependant.dart';

class DependantTile extends StatelessWidget {
  final Dependant dependant;
  final VoidCallback? onTap;

  const DependantTile({super.key, required this.dependant, this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = dependant.name.isNotEmpty
        ? dependant.name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: kPrimary.withValues(alpha: 0.12),
              child: Text(
                initials,
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dependant.name.isNotEmpty ? dependant.name : 'Member',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dependant.memberNo,
                    style: const TextStyle(fontSize: 12, color: kSubtext),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
              child: Text(
                dependant.relation,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kSubtext, size: 20),
          ],
        ),
      ),
    );
  }
}
