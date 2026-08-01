import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/dependant.dart';
import '../../providers/benefits_provider.dart';
import '../../providers/visits_provider.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/claim_status_chip.dart';
import '../benefits/benefits_screen.dart';
import 'dependant_claims_screen.dart';
import '../../core/app_colors.dart';

class DependantDetailScreen extends ConsumerWidget {
  final String memberNo;
  final Dependant? dependant;

  const DependantDetailScreen({
    super.key,
    required this.memberNo,
    this.dependant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name =
        dependant?.name.isNotEmpty == true ? dependant!.name : memberNo;
    final relation = dependant?.relation ?? 'Dependant';
    final benefit = dependant?.benefit;

    final benefitAsync = benefit != null
        ? null
        : ref.watch(benefitProvider(memberNo));
    final visitsAsync = ref.watch(visitsByMemberProvider(memberNo));

    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: Text(name,
            style: TextStyle(
                color: context.c.cardBg,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(kRadiusLg),
              boxShadow: kShadowMd,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: context.c.cardBg,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: context.c.cardBg,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memberNo,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(kRadiusFull),
                        ),
                        child: Text(
                          relation,
                          style: TextStyle(
                            color: context.c.cardBg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Benefits section
          Text(
            'Benefits',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.c.text),
          ),
          const SizedBox(height: 12),
          if (benefit != null)
            BenefitsView(benefit: benefit)
          else if (benefitAsync != null)
            benefitAsync.when(
              loading: () => const LoadingStatCardRow(),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Failed to load benefits',
                subtitle: e.toString(),
                buttonLabel: 'Retry',
                onButton: () =>
                    ref.invalidate(benefitProvider(memberNo)),
              ),
              data: (b) => BenefitsView(benefit: b),
            ),

          const SizedBox(height: 24),

          // Recent claims section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Claims',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.c.text),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DependantClaimsScreen(
                      memberNo: memberNo,
                      dependantName: name,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          visitsAsync.when(
            loading: () => const LoadingListCard(count: 3),
            error: (e, _) => const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No claims',
              subtitle: 'No claims found for this dependant.',
            ),
            data: (visits) {
              if (visits.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No claims',
                  subtitle: 'No claims found for this dependant.',
                );
              }
              final recent = visits.take(3).toList();
              return Column(
                children: [
                  ...recent.map((v) => _MiniClaimCard(
                        visit: v,
                        onTap: () => context.push(
                          '$routeClaims/${v.visitId}',
                          extra: {
                            'visit': v,
                            'memberNo': memberNo,
                          },
                        ),
                      )),
                  if (visits.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DependantClaimsScreen(
                                memberNo: memberNo,
                                dependantName: name,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: Text(
                              'View all ${visits.length} claims'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MiniClaimCard extends StatelessWidget {
  final dynamic visit;
  final VoidCallback onTap;

  const _MiniClaimCard({required this.visit, required this.onTap});

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kShadowSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.institution as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(visit.treatmentDate as String),
                    style: TextStyle(
                        fontSize: 11, color: context.c.subtext),
                  ),
                ],
              ),
            ),
            ClaimStatusChip(status: visit.claimStatus as String),
            const SizedBox(width: 8),
            Money(
              amount: visit.totalAmount as double,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
