import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/member.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/benefits_provider.dart';
import '../../providers/dependants_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/member_type_provider.dart';
import '../../providers/preauth_provider.dart';
import '../../providers/visits_provider.dart';
import '../../utils/benefit_forecast.dart' as bf;
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/section_header.dart' hide EmptyState;
import '../../widgets/common/visit_tile.dart';
import '../notifications/notifications_screen.dart';

// ── Dashboard background matches chronic dashboard ────────────────────────────
const _kBg = Color(0xFFF2F4F8);

class MemberDashboardScreen extends ConsumerWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).member;

    if (member == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Not signed in',
          subtitle: 'Please sign in to access your dashboard.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: () async {
          ref.invalidate(benefitProvider(member.memberNumber));
          ref.invalidate(familyVisitsProvider);
          ref.invalidate(preauthsProvider);
          ref.invalidate(dependantsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Hero gradient card ─────────────────────────────────────────
            SliverToBoxAdapter(child: _HeroCard(member: member)),

            // ── Body sections ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _BenefitsSummaryCard(memberNo: member.memberNumber),
                  const SizedBox(height: 24),
                  _RecentClaimsSection(memberNo: member.memberNumber),
                  const SizedBox(height: 24),
                  const _QuickActionsGrid(),
                  const SizedBox(height: 24),
                  Consumer(
                    builder: (ctx, ref, _) {
                      if (!ref.watch(isChronicMemberProvider)) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: const [
                          _ChronicCareTile(),
                          SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  const _WellnessTipCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final Member member;
  const _HeroCard({required this.member});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _initials() {
    final f = member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '';
    final l = member.lastName.isNotEmpty ? member.lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  String _relation() {
    if (member.relation != null && member.relation!.isNotEmpty) {
      return member.relation!;
    }
    return Member.relationFromMemberNumber(member.memberNumber);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(notificationsProvider).where((n) => !n.isRead).length;
    final visitsAsync = ref.watch(familyVisitsProvider);
    final dependantsAsync = ref.watch(dependantsProvider);

    // Profile picture: prefer Sanlam-side photo (base64), then live
    // memberProvider state, fall back to the auth member.
    final liveMember = ref.watch(memberProvider).member;
    final sanlamB64 = ref.watch(sanlamPhotoProvider);
    final profileIconRaw =
        (liveMember?.profileIcon?.trim().isNotEmpty ?? false)
            ? liveMember!.profileIcon!.trim()
            : (member.profileIcon?.trim() ?? '');

    // Derive YTD stats from loaded visits
    int claimsYtd = 0;
    double spentYtd = 0;
    final visitList = visitsAsync.valueOrNull;
    if (visitList != null) {
      final thisYear = DateTime.now().year;
      for (final v in visitList) {
        final date = v.treatmentDateParsed;
        if (date != null && date.year == thisYear) {
          claimsYtd++;
          spentYtd += v.totalAmount;
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Avatar + Greeting + Bell + Logout
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar — tap to open profile (logout moved next to bell)
                  GestureDetector(
                    onTap: () => context.push(routeProfile),
                    child: Builder(builder: (_) {
                      ImageProvider? img;
                      if (sanlamB64 != null && sanlamB64.isNotEmpty) {
                        try {
                          img = MemoryImage(base64Decode(sanlamB64));
                        } catch (_) {/* fall through */}
                      }
                      if (img == null && profileIconRaw.isNotEmpty) {
                        img = NetworkImage(profileIconRaw.startsWith('http')
                            ? profileIconRaw
                            : '$kServerBase$profileIconRaw');
                      }
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          image: img != null
                              ? DecorationImage(image: img, fit: BoxFit.cover)
                              : null,
                        ),
                        child: img != null
                            ? null
                            : Center(
                                child: Text(
                                  _initials(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  // Greeting + name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          member.firstName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Notification bell with unread badge
                  GestureDetector(
                    onTap: () => context.push(routeNotifications),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 18, minHeight: 18),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Logout — sits next to the bell
                  GestureDetector(
                    onTap: () => _confirmLogout(context, ref),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Scheme / Plan / Status / Relation pills
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (member.schemeName?.isNotEmpty == true)
                    _HeroPill(
                      label: member.schemeName!,
                      icon: Icons.shield_outlined,
                    ),
                  const _HeroPill(
                    label: 'Active',
                    icon: Icons.circle,
                    iconColor: Color(0xFF34C759),
                    iconSize: 8,
                  ),
                  _HeroPill(
                    label: _relation(),
                    icon: Icons.person_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stat strip — Claims YTD · Spent YTD · Dependants
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    _HeroStat(
                      label: 'Claims YTD',
                      value: visitsAsync.isLoading
                          ? '…'
                          : visitsAsync.hasError
                              ? '—'
                              : '$claimsYtd',
                      onTap: () => context.push(routeClaims),
                    ),
                    _HeroStatDivider(),
                    _HeroStat(
                      label: 'Spent YTD',
                      valueWidget: visitsAsync.isLoading
                          ? const Text(
                              '…',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : visitsAsync.hasError
                              ? const Text(
                                  '—',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : Money(
                                  amount: spentYtd,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                      onTap: () => context.push(routeClaims),
                    ),
                    _HeroStatDivider(),
                    _HeroStat(
                      label: 'Dependants',
                      value: dependantsAsync.when(
                        data: (d) => '${d.length}',
                        loading: () => '…',
                        error: (_, __) => '—',
                      ),
                      onTap: () => context.push(routeDependants),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;

  const _HeroPill({
    required this.label,
    required this.icon,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize ?? 12,
            color: iconColor ?? Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onTap;

  const _HeroStat(
      {required this.label, this.value, this.valueWidget, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        valueWidget ??
            Text(
              value ?? '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: content,
              ),
            )
          : content,
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  const _HeroStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

// ── Benefits Summary ──────────────────────────────────────────────────────────

class _BenefitsSummaryCard extends ConsumerWidget {
  final String memberNo;
  const _BenefitsSummaryCard({required this.memberNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefitAsync = ref.watch(benefitProvider(memberNo));
    final visitsAsync = ref.watch(familyVisitsProvider);

    double categorySpend(List<Visit> visits, bool Function(String) match) {
      final now = DateTime.now();
      return visits
          .where((v) {
            final d = v.treatmentDateParsed;
            if (d == null) return false;
            return d.year == now.year && match(v.treatmentType);
          })
          .fold<double>(0, (a, v) => a + v.totalAmount);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Your Benefits',
          actionLabel: 'View all',
          onAction: () => context.push(routeBenefits),
        ),
        const SizedBox(height: 12),
        benefitAsync.when(
          loading: () => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: List.generate(
              4,
              (_) => Shimmer.fromColors(
                baseColor: const Color(0xFFE2E8F0),
                highlightColor: const Color(0xFFF8FAFC),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: kError, size: 28),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load benefits',
                  style: TextStyle(
                    color: kText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref.invalidate(benefitProvider(memberNo)),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (benefit) {
            final visits = visitsAsync.asData?.value ?? const <Visit>[];
            final visitsLoaded = visitsAsync is AsyncData<List<Visit>>;
            final outSpent = categorySpend(visits, bf.isOutPatient);
            final inSpent = categorySpend(visits, bf.isInPatient);
            final dentalSpent = categorySpend(visits, bf.isDental);
            final opticalSpent = categorySpend(visits, bf.isOptical);

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _BenefitMiniCard(
                  label: 'Outpatient',
                  icon: Icons.local_hospital_rounded,
                  color: kPrimary,
                  allocation: benefit.outPatient,
                  spent: outSpent,
                  showSpent: visitsLoaded,
                  onTap: () => context.push(routeBenefits),
                ),
                _BenefitMiniCard(
                  label: 'Inpatient',
                  icon: Icons.bed_rounded,
                  color: kAccentAmber,
                  allocation: benefit.inPatient,
                  spent: inSpent,
                  showSpent: visitsLoaded,
                  onTap: () => context.push(routeBenefits),
                ),
                _BenefitMiniCard(
                  label: 'Dental',
                  icon: Icons.sentiment_satisfied_rounded,
                  color: kSuccess,
                  allocation: benefit.dental,
                  spent: dentalSpent,
                  showSpent: visitsLoaded,
                  onTap: () => context.push(routeBenefits),
                ),
                _BenefitMiniCard(
                  label: 'Optical',
                  icon: Icons.visibility_rounded,
                  color: kPurple,
                  allocation: benefit.optical,
                  spent: opticalSpent,
                  showSpent: visitsLoaded,
                  onTap: () => context.push(routeBenefits),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BenefitMiniCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double allocation;
  final double spent;
  final bool showSpent;
  final VoidCallback onTap;

  const _BenefitMiniCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.allocation,
    required this.spent,
    required this.showSpent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining =
        (allocation - spent).clamp(0, double.infinity).toDouble();
    final pct = allocation > 0
        ? (spent / allocation).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kShadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                  ),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSubtext,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.45),
                  size: 16,
                ),
              ],
            ),
            const Spacer(),
            const Text(
              'Balance',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: kSubtext,
              ),
            ),
            const SizedBox(height: 1),
            Money(
              amount: showSpent ? remaining : allocation,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kText,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: showSpent ? pct : null,
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showSpent ? 'Used' : '',
                  style: const TextStyle(fontSize: 9, color: kSubtext),
                ),
                if (showSpent)
                  Money(
                    amount: spent,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: kSubtext,
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

// ── Recent Claims ─────────────────────────────────────────────────────────────

class _RecentClaimsSection extends ConsumerWidget {
  final String memberNo;
  const _RecentClaimsSection({required this.memberNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(familyVisitsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Claims',
          actionLabel: 'View all',
          onAction: () => context.push(routeClaims),
        ),
        const SizedBox(height: 12),
        visitsAsync.when(
          loading: () => const LoadingListCard(count: 1),
          error: (e, _) => EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Could not load claims',
            subtitle: e.toString(),
            buttonLabel: 'Retry',
            onButton: () => ref.invalidate(familyVisitsProvider),
          ),
          data: (visits) {
            if (visits.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No claims yet',
                subtitle: 'Your recent medical claims will appear here.',
              );
            }
            final top = visits.take(1).toList();
            return Column(
              children: top
                  .map((v) => VisitTile(
                        visit: v,
                        onTap: () => context.push(
                          '$routeClaims/${v.visitId}',
                          extra: {'visit': v, 'memberNo': memberNo},
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QA(this.label, this.icon, this.color, this.route);
}

class _QuickActionsGrid extends ConsumerWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChronic = ref.watch(isChronicMemberProvider);
    final actions = <_QA>[
      const _QA('Membership\nCard', Icons.badge_rounded, kPrimary, routeMembershipCard),
      const _QA('Pre-Auths', Icons.verified_user_rounded, kAccentAmber, routePreauths),
      const _QA('Prescriptions', Icons.medication_liquid_rounded,
          Color(0xFF0891B2), routePrescriptions),
      const _QA('Reimburse', Icons.receipt_long_rounded,
          Color(0xFFEF4444), routeReimbursement),
      const _QA('Dependants', Icons.family_restroom_rounded, kAccent, routeDependants),
      const _QA('Find Hospital', Icons.local_hospital_rounded,
          Color(0xFF059669), routeNetwork),
      const _QA('Vitals', Icons.monitor_heart_rounded,
          Color(0xFF007AFF), routeVitals),
      const _QA('Lifestyle', Icons.self_improvement_rounded,
          Color(0xFF34C759), routeLifestyle),
      if (isChronic)
        const _QA('Medications', Icons.medication_rounded,
            Color(0xFFFF9500), routeMedications),
      const _QA('Education', Icons.menu_book_rounded, kPurple, routeEducation),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: actions.map((a) => _QATile(action: a)).toList(),
        ),
      ],
    );
  }
}

class _QATile extends StatelessWidget {
  final _QA action;
  const _QATile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(action.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: [
            BoxShadow(
              color: action.color.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: action.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: Colors.white, size: 17),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                action.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: kText,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chronic Care Tile ─────────────────────────────────────────────────────────

class _ChronicCareTile extends StatelessWidget {
  const _ChronicCareTile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/chronic'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE53935), Color(0xFFFF6B35)],
          ),
          borderRadius: BorderRadius.circular(kRadiusLg),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open Chronic Care Centre',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your conditions, treatment plans and lab results',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wellness Tip ──────────────────────────────────────────────────────────────

class _WellnessTipCard extends StatefulWidget {
  const _WellnessTipCard();

  @override
  State<_WellnessTipCard> createState() => _WellnessTipCardState();
}

class _WellnessTipCardState extends State<_WellnessTipCard> {
  late final String _tip;

  @override
  void initState() {
    super.initState();
    _tip = kWellnessTips[math.Random().nextInt(kWellnessTips.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kShadowSm,
        border: Border.all(color: kSuccess.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: kSuccess,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wellness Tip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kSuccess,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tip,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
