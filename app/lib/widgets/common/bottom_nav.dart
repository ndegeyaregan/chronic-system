import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  int _locationToIndex(String location) {
    if (location.startsWith('/home/chronic')) return 0;
    if (location == routeDashboard) return 0;
    if (location.startsWith(routeBenefits)) return 1;
    if (location.startsWith(routeClaims)) return 2;
    if (location.startsWith(routeFacilityFinder)) return 3;
    if (location.startsWith(routeProfile)) return 4;
    return -1; // sub-page that doesn't belong to any tab — no tab active
  }

  String _indexToRoute(int index) {
    switch (index) {
      case 1:
        return routeBenefits;
      case 2:
        return routeClaims;
      case 3:
        return routeFacilityFinder;
      case 4:
        return routeProfile;
      default:
        return routeDashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);
    final isChronicDash = location.startsWith('/home/chronic');

    final items = [
      _NavItem(
        icon: isChronicDash ? Icons.favorite_rounded : Icons.home_rounded,
        label: isChronicDash ? 'Care' : 'Home',
        color: const Color(0xFF007AFF),
      ),
      _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Benefits', color: const Color(0xFF32ADE6)),
      _NavItem(icon: Icons.receipt_long_rounded,           label: 'Claims',   color: const Color(0xFF34C759)),
      _NavItem(icon: Icons.local_hospital_rounded,         label: 'Facility', color: const Color(0xFFFF9500)),
      _NavItem(icon: Icons.person_rounded,                 label: 'Profile',  color: const Color(0xFFFF3B30)),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return _NavButton(
                item: items[i],
                isActive: isActive,
                onTap: () {
                  if (!isActive) context.go(_indexToRoute(i));
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  const _NavItem({required this.icon, required this.label, required this.color});
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton(
      {required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = item.color;
    // Inactive icon = neutral gray with strong contrast (was a faint
    // 38% tint of the brand color which members reported as "looks disabled").
    const inactiveColor = Color(0xFF6B7280); // slate-500: clearly visible on white
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
            horizontal: isActive ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? col.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon,
                size: 24,
                color: isActive ? col : inactiveColor),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  color: col,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
