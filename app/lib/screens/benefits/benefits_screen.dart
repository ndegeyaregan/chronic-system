import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/benefit.dart';
import '../../models/visit.dart';
import '../../providers/benefits_provider.dart';
import '../../providers/dependants_provider.dart';
import '../../providers/visits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/benefit_forecast.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../services/notification_service.dart';
import '../../core/app_colors.dart';

// ── Warning thresholds (UGX) ──────────────────────────────────────────────
const double _kWarnOutpatient = 500000;
const double _kWarnInpatient  = 500000;
const double _kWarnDental     = 100000;
const double _kWarnOptical    = 100000;

// Guard so we fire at most one device notification per app session.
final _notifiedLowBalanceKeys = <String>{};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<Visit> _ytdVisits(List<Visit> visits) {
  final now = DateTime.now();
  return visits.where((v) {
    final d = v.treatmentDateParsed;
    return d != null && d.year == now.year && !d.isAfter(now);
  }).toList();
}

double _spendFor(List<Visit> visits, bool Function(String) match) {
  double s = 0;
  for (final v in visits) {
    if (match(v.treatmentType)) s += v.totalAmount;
  }
  return s;
}

int _countFor(List<Visit> visits, bool Function(String) match) {
  int n = 0;
  for (final v in visits) {
    if (match(v.treatmentType)) n++;
  }
  return n;
}

String _claimCountLabel(int n) =>
    n == 0 ? 'No claim' : (n == 1 ? '1 claim' : '$n claims');

String _shortAmount(double v) {
  if (v >= 1000000) {
    return '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}M';
  }
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BenefitsScreen extends ConsumerWidget {
  const BenefitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).member;
    if (member == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Not signed in',
          subtitle: 'Please sign in to view your benefits.',
        ),
      );
    }

    final benefitAsync = ref.watch(benefitProvider(member.memberNumber));
    final visitsAsync = ref.watch(familyVisitsProvider);
    final dependantsAsync = ref.watch(dependantsProvider);

    final isPrincipal =
        member.memberNumber.endsWith('-00') || (member.relation ?? '')
                .trim()
                .toLowerCase() ==
            'principal';
    final dependantCount = dependantsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: Text('My Benefits',
            style: TextStyle(
                color: context.c.cardBg,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: benefitAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            LoadingStatCardRow(),
            SizedBox(height: 16),
            LoadingStatCardRow(),
          ],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load benefits',
          subtitle: e.toString(),
          buttonLabel: 'Retry',
          onButton: () => ref.invalidate(benefitProvider(member.memberNumber)),
        ),
        data: (benefit) {
          final visits = visitsAsync.valueOrNull ?? const <Visit>[];
          final loadingVisits = visitsAsync.isLoading;
          final ytd = _ytdVisits(visits);

          final advice = loadingVisits
              ? null
              : buildBenefitAdvice(benefit: benefit, visits: visits);

          // Fire a single device notification per session for each low pool.
          final lowPools = <({String key, String name, double balance, double threshold})>[
            if (benefit.outPatient > 0 && benefit.outPatient < _kWarnOutpatient)
              (key: 'outpatient', name: 'Outpatient', balance: benefit.outPatient, threshold: _kWarnOutpatient),
            if (benefit.inPatient > 0 && benefit.inPatient < _kWarnInpatient)
              (key: 'inpatient', name: 'Inpatient', balance: benefit.inPatient, threshold: _kWarnInpatient),
            if (benefit.dental > 0 && benefit.dental < _kWarnDental)
              (key: 'dental', name: 'Dental', balance: benefit.dental, threshold: _kWarnDental),
            if (benefit.optical > 0 && benefit.optical < _kWarnOptical)
              (key: 'optical', name: 'Optical', balance: benefit.optical, threshold: _kWarnOptical),
          ];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (final p in lowPools) {
              if (_notifiedLowBalanceKeys.add(p.key)) {
                final fmt = p.balance >= 1000000
                    ? '${(p.balance / 1000000).toStringAsFixed(1)}M'
                    : p.balance >= 1000
                        ? '${(p.balance / 1000).toStringAsFixed(0)}K'
                        : p.balance.toStringAsFixed(0);
                NotificationService.show(
                  id: 600 + lowPools.indexOf(p),
                  title: '⚠️ ${p.name} pool running low',
                  body:
                      'Your ${p.name.toLowerCase()} balance is UGX $fmt — below the UGX ${(p.threshold ~/ 1000)}K minimum. Contact your HR officer.',
                  payload: 'benefits',
                );
              }
            }
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(benefitProvider(member.memberNumber));
              ref.invalidate(familyVisitsProvider);
              ref.invalidate(dependantsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _ScopeChip(
                  isPrincipal: isPrincipal,
                  dependantCount: dependantCount,
                ),
                const SizedBox(height: 12),
                if (lowPools.isNotEmpty) ...[
                  _LowBalanceBanner(pools: lowPools.map((p) => p.name).toList()),
                  const SizedBox(height: 12),
                ],
                if (advice != null) ...[
                  _AdvisorCardPremium(advice: advice),
                  const SizedBox(height: 14),
                ],
                _CategoryGrid(
                  benefit: benefit,
                  visits: ytd,
                  advice: advice,
                ),
                const SizedBox(height: 14),
                _RecentClaimsLink(count: ytd.length),
                if (benefit.coPayActive) ...[
                  const SizedBox(height: 14),
                  _CoPayBanner(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scope chip — tells user whether totals are family-wide or personal
// ─────────────────────────────────────────────────────────────────────────────

class _ScopeChip extends StatelessWidget {
  final bool isPrincipal;
  final int dependantCount;
  const _ScopeChip({required this.isPrincipal, required this.dependantCount});

  @override
  Widget build(BuildContext context) {
    final text = isPrincipal
        ? (dependantCount > 0
            ? 'Family pool — you + $dependantCount ${dependantCount == 1 ? "dependant" : "dependants"}'
            : 'Your benefit pool')
        : 'Your personal claims (under family pool)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(kRadiusFull),
        border: Border.all(color: kPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom_rounded,
              color: kPrimary, size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: kPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advisor — premium tone
// ─────────────────────────────────────────────────────────────────────────────

class _AdvisorCardPremium extends StatelessWidget {
  final BenefitAdvice advice;
  const _AdvisorCardPremium({required this.advice});

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(advice.overallSeverity);
    final atRisk = advice.atRiskCategories;

    return Container(
      decoration: BoxDecoration(
        color: context.c.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(color: tone.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: tone.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(kRadiusLg)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tone.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tone.label,
                          style: TextStyle(
                              color: tone.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('Smart Forecast',
                          style: TextStyle(
                              color: context.c.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.headline,
                  style: TextStyle(
                      color: context.c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  advice.recommendation,
                  style: TextStyle(
                      color: context.c.subtext, fontSize: 12.5, height: 1.45),
                ),
                if (atRisk.isNotEmpty || advice.byCategory.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(height: 1, color: context.c.border),
                  const SizedBox(height: 10),
                  Text(
                    'BY POOL',
                    style: TextStyle(
                        color: context.c.subtext,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  // Always show outpatient + inpatient (the two core pillars)
                  // followed by any other at-risk pools (dental/optical).
                  ..._coreAndAtRisk(advice).map((c) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _ForecastRow(forecast: c),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the forecast rows the advisor card should always show:
  /// outpatient + inpatient first, then any other at-risk pools.
  List<CategoryForecast> _coreAndAtRisk(BenefitAdvice advice) {
    final out = <CategoryForecast>[];
    CategoryForecast? pick(String name) {
      for (final f in advice.byCategory) {
        if (f.category == name) return f;
      }
      return null;
    }
    final op = pick('Outpatient');
    final ip = pick('Inpatient');
    if (op != null) out.add(op);
    if (ip != null) out.add(ip);
    for (final c in advice.atRiskCategories) {
      if (c.category != 'Outpatient' && c.category != 'Inpatient') {
        out.add(c);
      }
    }
    return out;
  }
}

class _ForecastRow extends StatelessWidget {
  final CategoryForecast forecast;
  const _ForecastRow({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(forecast.severity);

    String pillText;
    if (forecast.remaining <= 0) {
      pillText = 'Fully utilised';
    } else if (forecast.severity == ForecastSeverity.noActivity) {
      pillText = 'No claims yet';
    } else {
      pillText = 'On track';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 28,
          decoration: BoxDecoration(
              color: tone.color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(forecast.category,
                  style: TextStyle(
                      color: context.c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'Burn UGX ${_shortAmount(forecast.monthlyBurn)}/mo',
                style: TextStyle(color: context.c.subtext, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tone.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kRadiusFull),
          ),
          child: Text(pillText,
              style: TextStyle(
                  color: tone.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allocation grid — 2x2 compact category cards
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final Benefit benefit;
  final List<Visit> visits;
  const _CategoryGrid({
    required this.benefit,
    required this.visits,
    BenefitAdvice? advice,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <_AllocCard>[
      _AllocCard(
        icon: Icons.local_hospital_outlined,
        label: 'Outpatient',
        allocation: benefit.outPatient,
        spent: _spendFor(visits, isOutPatient),
        claimCount: _countFor(visits, isOutPatient),
        color: kPrimary,
        warnThreshold: _kWarnOutpatient,
      ),
      _AllocCard(
        icon: Icons.bed_outlined,
        label: 'Inpatient',
        allocation: benefit.inPatient,
        spent: _spendFor(visits, isInPatient),
        claimCount: _countFor(visits, isInPatient),
        color: kPurple,
        warnThreshold: _kWarnInpatient,
      ),
      _AllocCard(
        icon: Icons.medical_services_outlined,
        label: 'Dental',
        allocation: benefit.dental,
        spent: _spendFor(visits, isDental),
        claimCount: _countFor(visits, isDental),
        color: kSuccess,
        warnThreshold: _kWarnDental,
      ),
      _AllocCard(
        icon: Icons.visibility_outlined,
        label: 'Optical',
        allocation: benefit.optical,
        spent: _spendFor(visits, isOptical),
        claimCount: _countFor(visits, isOptical),
        color: kAccentAmber,
        warnThreshold: _kWarnOptical,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final width = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((e) => SizedBox(width: width, child: e)).toList(),
      );
    });
  }
}

class _AllocCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double allocation;
  final double spent;
  final int claimCount;
  final Color color;
  final double warnThreshold;

  const _AllocCard({
    required this.icon,
    required this.label,
    required this.allocation,
    required this.spent,
    required this.claimCount,
    required this.color,
    this.warnThreshold = 0,
  });

  @override
  Widget build(BuildContext context) {
    // The Sanlam API returns the *current available balance* per
    // category. Display it directly. Visit-based "spent" is shown only
    // as informative context; we don't subtract it from balance.
    final remaining = allocation;
    final hasBalance = remaining > 0;
    final spentDisplay = spent;
    final isLow = warnThreshold > 0 && remaining > 0 && remaining < warnThreshold;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(
          color: isLow ? kAccentAmber.withValues(alpha: 0.8) : context.c.border,
          width: isLow ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              if (hasBalance)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(kRadiusFull),
                  ),
                  child: Text('Available',
                      style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: context.c.subtext,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text('UGX ${_shortAmount(remaining)}',
              style: TextStyle(
                  color: context.c.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(
              spentDisplay > 0
                  ? 'YTD claimed: UGX ${_shortAmount(spentDisplay)}'
                  : 'Balance available',
              style: TextStyle(color: context.c.subtext, fontSize: 10.5)),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(kRadiusFull),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 11, color: color),
                const SizedBox(width: 4),
                Text(
                  _claimCountLabel(claimCount),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isLow) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: kAccentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kAccentAmber.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 13, color: kAccentAmber),
                  const SizedBox(width: 5),
                  const Expanded(
                    child: Text(
                      'Low balance — contact HR',
                      style: TextStyle(
                          color: kAccentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Low-balance summary banner
// ─────────────────────────────────────────────────────────────────────────────

class _LowBalanceBanner extends StatelessWidget {
  final List<String> pools;
  const _LowBalanceBanner({required this.pools});

  @override
  Widget build(BuildContext context) {
    final names = pools.join(' & ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kAccentAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kAccentAmber.withValues(alpha: 0.50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded,
                color: kAccentAmber, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Benefit Pool Warning',
                  style: TextStyle(
                      color: kAccentAmber,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your $names ${pools.length == 1 ? "pool is" : "pools are"} running low. '
                  'Please contact your HR officer or Sanlam Allianz Uganda to arrange a top-up.',
                  style: TextStyle(
                      color: context.c.text, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Recent claims link — taps through to claims screen
// ─────────────────────────────────────────────────────────────────────────────

class _RecentClaimsLink extends StatelessWidget {
  final int count;
  const _RecentClaimsLink({required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(routeClaims),
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.c.cardBg,
          borderRadius: BorderRadius.circular(kRadiusLg),
          boxShadow: kCardShadow,
          border: Border.all(color: context.c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_outlined,
                  color: kPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View all claims',
                      style: TextStyle(
                          color: context.c.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(
                    count == 0
                        ? 'No claims this year'
                        : '$count claim${count == 1 ? "" : "s"} this year',
                    style: TextStyle(
                        color: context.c.subtext, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 13, color: context.c.subtext),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Co-pay banner
// ─────────────────────────────────────────────────────────────────────────────

class _CoPayBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAccentAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kAccentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: kAccentAmber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('Co-payment is active on your plan.',
                style: TextStyle(
                    fontSize: 12.5,
                    color: kAccentAmber,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tone palette
// ─────────────────────────────────────────────────────────────────────────────

class _Tone {
  final Color color;
  final IconData icon;
  final String label;
  const _Tone(this.color, this.icon, this.label);
}

_Tone _toneFor(ForecastSeverity s) {
  switch (s) {
    case ForecastSeverity.critical:
      return const _Tone(kError, Icons.warning_amber_rounded, 'ACTION NEEDED');
    case ForecastSeverity.watch:
      return const _Tone(kAccentAmber, Icons.trending_up_rounded, 'WATCH');
    case ForecastSeverity.onTrack:
      return const _Tone(kSuccess, Icons.check_circle_outline, 'ON TRACK');
    case ForecastSeverity.noActivity:
      return const _Tone(kPrimary, Icons.lightbulb_outline, 'TIP');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BenefitsView (kept for reuse on other screens — e.g. dependant detail)
// ─────────────────────────────────────────────────────────────────────────────

class BenefitsView extends StatelessWidget {
  final Benefit benefit;
  final List<Visit> visits;

  const BenefitsView({
    super.key,
    required this.benefit,
    this.visits = const <Visit>[],
  });

  @override
  Widget build(BuildContext context) {
    final ytd = _ytdVisits(visits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (benefit.coPayActive) ...[
          _CoPayBanner(),
          const SizedBox(height: 12),
        ],
        _CategoryGrid(benefit: benefit, visits: ytd),
      ],
    );
  }
}

// Re-exported for any external caller still importing the old advisor card.
class BenefitsAdvisorCard extends StatelessWidget {
  final BenefitAdvice advice;
  const BenefitsAdvisorCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) => _AdvisorCardPremium(advice: advice);
}
