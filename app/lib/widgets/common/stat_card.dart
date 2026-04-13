import 'package:flutter/material.dart';
import '../../core/constants.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? bgColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.bgColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? kPrimary;
    final bg = bgColor ?? kPrimary.withOpacity(0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? Colors.white : null,
          borderRadius: BorderRadius.circular(kRadiusLg),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gradient != null
                    ? Colors.white.withOpacity(0.25)
                    : bg,
                borderRadius: BorderRadius.circular(kRadiusSm + 2),
              ),
              child: Icon(icon,
                  color: gradient != null ? Colors.white : ic, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: gradient != null ? Colors.white : kText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: gradient != null
                    ? Colors.white.withOpacity(0.85)
                    : kSubtext,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gradient != null
                      ? Colors.white.withOpacity(0.2)
                      : ic.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(kRadiusFull),
                ),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: gradient != null ? Colors.white : ic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isAlert;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.trend,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isAlert ? kError : color;
    final statusColor = isAlert ? kError : kSuccess;
    final statusLabel = isAlert
        ? (trend == '↓' ? 'Low' : 'High')
        : 'Normal';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
        boxShadow: kCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Label + icon row
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isAlert ? accent : kSubtext,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isAlert ? kError : kText,
                      height: 1,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    unit,
                    style: const TextStyle(
                        fontSize: 10, color: kSubtext),
                  ),
                ),
              ],
            ),
            // Status row
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    trend == '↑'
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_forward_rounded,
                    size: 10,
                    color: statusColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}