import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/benefit.dart';
import '../../models/visit.dart';
import '../../providers/benefits_provider.dart';
import '../../providers/dependants_provider.dart';
import '../../providers/visits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/benefit_forecast.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';

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

String _shortAmount(double v) {
  if (v >= 1000000) {
    return '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}M';
  }
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
  return v.toStringAsFixed(0);
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _monthYearShort(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.year}';

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
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text('My Benefits',
            style: TextStyle(
                color: Colors.white,
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
          final ytdSpend = ytd.fold<double>(0, (a, v) => a + v.totalAmount);
          final totalAllocation = benefit.totalAllocation == 0
              ? (benefit.outPatient +
                  benefit.inPatient +
                  benefit.dental +
                  benefit.optical)
              : benefit.totalAllocation;

          final advice = loadingVisits
              ? null
              : buildBenefitAdvice(benefit: benefit, visits: visits);

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
                _PoolHeroCard(
                  totalAllocation: totalAllocation,
                  ytdSpend: ytdSpend,
                  visitsCount: ytd.length,
                  loading: loadingVisits,
                ),
                const SizedBox(height: 14),
                if (advice != null) ...[
                  _AdvisorCardPremium(advice: advice),
                  const SizedBox(height: 14),
                ],
                _CategoryGrid(benefit: benefit, visits: ytd),
                const SizedBox(height: 14),
                _SpendByCategoryCard(visits: ytd),
                const SizedBox(height: 14),
                _MonthlyTrendCard(visits: visits),
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
// Hero pool card — radial ring + summary
// ─────────────────────────────────────────────────────────────────────────────

class _PoolHeroCard extends StatelessWidget {
  final double totalAllocation;
  final double ytdSpend;
  final int visitsCount;
  final bool loading;

  const _PoolHeroCard({
    required this.totalAllocation,
    required this.ytdSpend,
    required this.visitsCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final remaining =
        (totalAllocation - ytdSpend).clamp(0, double.infinity).toDouble();
    final ratio =
        totalAllocation <= 0 ? 0.0 : (ytdSpend / totalAllocation).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    final avg = visitsCount == 0 ? 0.0 : ytdSpend / visitsCount;

    final ringColor = ratio >= 0.85
        ? kError
        : ratio >= 0.6
            ? kAccentAmber
            : kAccentLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryDark, kPrimary, kPrimaryLight],
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: [
          BoxShadow(
              color: kPrimary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: loading ? null : ratio,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loading ? '…' : '$pct%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'used',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YTD Spend',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 4),
                    Money(
                      amount: ytdSpend,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('of ${formatMoney(totalAllocation, "UGX")} pool',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(kRadiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            '${formatMoney(remaining, "UGX")} left',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroFooterStat(
                  label: 'Claims YTD',
                  value: visitsCount.toString(),
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.18)),
              Expanded(
                child: _HeroFooterStat(
                  label: 'Avg / visit',
                  value: visitsCount == 0
                      ? '—'
                      : 'UGX ${_shortAmount(avg)}',
                  icon: Icons.payments_outlined,
                ),
              ),
              Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.18)),
              Expanded(
                child: _HeroFooterStat(
                  label: 'Pool left',
                  value: 'UGX ${_shortAmount(remaining)}',
                  icon: Icons.savings_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFooterStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroFooterStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 14),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10.5,
                fontWeight: FontWeight.w500)),
      ],
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
        color: Colors.white,
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
                      const Text('Smart Forecast',
                          style: TextStyle(
                              color: kText,
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
                  style: const TextStyle(
                      color: kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  advice.recommendation,
                  style: const TextStyle(
                      color: kSubtext, fontSize: 12.5, height: 1.45),
                ),
                if (atRisk.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 10),
                  const Text(
                    'AT RISK',
                    style: TextStyle(
                        color: kSubtext,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  ...atRisk.map((c) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _ForecastRow(forecast: c),
                      )),
                ] else if (advice.overall.depletionDate != null &&
                    advice.overall.depletesThisYear) ...[
                  const SizedBox(height: 14),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 10),
                  _ForecastRow(forecast: advice.overall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final CategoryForecast forecast;
  const _ForecastRow({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(forecast.severity);
    final months = forecast.monthsRemaining;
    final date = forecast.depletionDate;

    String runway;
    if (forecast.remaining <= 0) {
      runway = 'Fully utilised';
    } else if (months == null) {
      runway = '—';
    } else if (months >= 12) {
      runway = '> 12 mo left';
    } else if (months >= 1) {
      runway = '${months.toStringAsFixed(months >= 3 ? 0 : 1)} mo left';
    } else {
      runway = '< 1 mo left';
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
                  style: const TextStyle(
                      color: kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                date != null && forecast.depletesThisYear
                    ? 'Runs out ~${_monthYearShort(date)} • UGX ${_shortAmount(forecast.monthlyBurn)}/mo'
                    : 'Burn UGX ${_shortAmount(forecast.monthlyBurn)}/mo',
                style: const TextStyle(color: kSubtext, fontSize: 11.5),
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
          child: Text(runway,
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
  const _CategoryGrid({required this.benefit, required this.visits});

  @override
  Widget build(BuildContext context) {
    final cards = <_AllocCard>[
      _AllocCard(
        icon: Icons.local_hospital_outlined,
        label: 'Outpatient',
        allocation: benefit.outPatient,
        spent: _spendFor(visits, isOutPatient),
        color: kPrimary,
      ),
      _AllocCard(
        icon: Icons.bed_outlined,
        label: 'Inpatient',
        allocation: benefit.inPatient,
        spent: _spendFor(visits, isInPatient),
        color: kPurple,
      ),
      _AllocCard(
        icon: Icons.medical_services_outlined,
        label: 'Dental',
        allocation: benefit.dental,
        spent: _spendFor(visits, isDental),
        color: kSuccess,
      ),
      _AllocCard(
        icon: Icons.visibility_outlined,
        label: 'Optical',
        allocation: benefit.optical,
        spent: _spendFor(visits, isOptical),
        color: kAccentAmber,
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
  final Color color;

  const _AllocCard({
    required this.icon,
    required this.label,
    required this.allocation,
    required this.spent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = allocation <= 0 ? 0.0 : (spent / allocation);
    final clamped = ratio.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    final remaining =
        (allocation - spent).clamp(0, double.infinity).toDouble();
    final danger = clamped >= 0.85;
    final fill = danger ? kError : color;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorder),
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
              if (allocation > 0)
                Text('$pct%',
                    style: TextStyle(
                        color: fill,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: kSubtext,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text('UGX ${_shortAmount(remaining)}',
              style: const TextStyle(
                  color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text('left of UGX ${_shortAmount(allocation)}',
              style: const TextStyle(color: kSubtext, fontSize: 10.5)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadiusFull),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spend by category (donut + legend)
// ─────────────────────────────────────────────────────────────────────────────

class _SpendByCategoryCard extends StatelessWidget {
  final List<Visit> visits;
  const _SpendByCategoryCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    final entries = <_CatEntry>[
      _CatEntry('Outpatient', _spendFor(visits, isOutPatient), kPrimary),
      _CatEntry('Inpatient', _spendFor(visits, isInPatient), kPurple),
      _CatEntry('Dental', _spendFor(visits, isDental), kSuccess),
      _CatEntry('Optical', _spendFor(visits, isOptical), kAccentAmber),
    ];
    final positives = entries.where((e) => e.amount > 0).toList();
    final total = positives.fold<double>(0, (a, e) => a + e.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spend by Category',
              style: TextStyle(
                  color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('Year-to-date breakdown',
              style: TextStyle(color: kSubtext, fontSize: 11.5)),
          const SizedBox(height: 14),
          if (total <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No spend recorded yet this year.',
                    style: TextStyle(color: kSubtext, fontSize: 12.5)),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices: positives
                          .map((e) => _Slice(e.amount / total, e.color))
                          .toList(),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_shortAmount(total),
                              style: const TextStyle(
                                  color: kText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          const Text('UGX',
                              style: TextStyle(
                                  color: kSubtext,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: positives
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _LegendRow(
                                label: e.label,
                                amount: e.amount,
                                pct: total <= 0 ? 0 : (e.amount / total),
                                color: e.color,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CatEntry {
  final String label;
  final double amount;
  final Color color;
  _CatEntry(this.label, this.amount, this.color);
}

class _LegendRow extends StatelessWidget {
  final String label;
  final double amount;
  final double pct;
  final Color color;
  const _LegendRow(
      {required this.label,
      required this.amount,
      required this.pct,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Text('UGX ${_shortAmount(amount)}',
            style: const TextStyle(
                color: kText, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('${(pct * 100).round()}%',
            style: const TextStyle(
                color: kSubtext, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Slice {
  final double ratio;
  final Color color;
  _Slice(this.ratio, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = 14.0;
    final inner = rect.deflate(stroke / 2);
    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.ratio * math.pi * 2;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(inner, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly trend bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyTrendCard extends StatelessWidget {
  final List<Visit> visits;
  const _MonthlyTrendCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List<DateTime>.generate(
      6,
      (i) => DateTime(now.year, now.month - (5 - i), 1),
    );
    final totals = List<double>.filled(6, 0);
    for (final v in visits) {
      final d = v.treatmentDateParsed;
      if (d == null) continue;
      for (var i = 0; i < months.length; i++) {
        final m = months[i];
        if (d.year == m.year && d.month == m.month) {
          totals[i] += v.totalAmount;
          break;
        }
      }
    }
    final maxVal = totals.fold<double>(0, (a, b) => b > a ? b : a);
    final hasData = maxVal > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Spend Trend',
              style: TextStyle(
                  color: kText, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('Last 6 months',
              style: TextStyle(color: kSubtext, fontSize: 11.5)),
          const SizedBox(height: 16),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No claims in the last 6 months.',
                    style: TextStyle(color: kSubtext, fontSize: 12.5)),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(months.length, (i) {
                  final value = totals[i];
                  final ratio = maxVal <= 0 ? 0.0 : (value / maxVal);
                  final h = value <= 0 ? 4.0 : (8 + ratio * 92);
                  final isCurrent = i == months.length - 1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (value > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _shortAmount(value),
                                style: TextStyle(
                                    color: isCurrent ? kPrimary : kSubtext,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          Container(
                            height: h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isCurrent
                                    ? [kPrimary, kPrimaryLight]
                                    : [
                                        kPrimary.withValues(alpha: 0.35),
                                        kPrimary.withValues(alpha: 0.18),
                                      ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(months.length, (i) {
              final isCurrent = i == months.length - 1;
              return Expanded(
                child: Text(
                  _monthAbbr[months[i].month - 1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isCurrent ? kPrimary : kSubtext,
                      fontSize: 11,
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w500),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusLg),
          boxShadow: kCardShadow,
          border: Border.all(color: kBorder),
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
                  const Text('View all claims',
                      style: TextStyle(
                          color: kText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(
                    count == 0
                        ? 'No claims this year'
                        : '$count claim${count == 1 ? "" : "s"} this year',
                    style: const TextStyle(
                        color: kSubtext, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 13, color: kSubtext),
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
