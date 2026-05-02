import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/preauth.dart';
import '../../providers/preauth_provider.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';

/// Tracks which status filter is selected. `null` == All.
final preauthStatusFilterProvider =
    StateProvider<PreauthStatus?>((_) => null);

class PreauthListScreen extends ConsumerWidget {
  const PreauthListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(preauthStatusFilterProvider);
    final preauthsAsync = ref.watch(preauthsProvider(filter));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'Pre-Authorisations',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StatusFilterBar(
            selected: filter,
            onChanged: (v) =>
                ref.read(preauthStatusFilterProvider.notifier).state = v,
          ),
        ),
      ),
      body: preauthsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [LoadingListCard(count: 4)],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Failed to load pre-authorisations',
          subtitle: e.toString(),
          buttonLabel: 'Retry',
          onButton: () => ref.invalidate(preauthsProvider(filter)),
        ),
        data: (preauths) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(preauthsProvider(filter)),
          child: preauths.isEmpty
              ? ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                    EmptyState(
                      icon: Icons.assignment_outlined,
                      title: filter == null
                          ? 'No pre-authorisations'
                          : 'No ${filter.label.toLowerCase()} requests',
                      subtitle: filter == null
                          ? 'Pre-authorisation requests will appear here once submitted.'
                          : 'Try a different filter to see other requests.',
                    ),
                  ],
                )
              : _PreauthSections(items: preauths),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final PreauthStatus? selected;
  final ValueChanged<PreauthStatus?> onChanged;

  const _StatusFilterBar({required this.selected, required this.onChanged});

  static const _options = <(PreauthStatus?, String)>[
    (null, 'All'),
    (PreauthStatus.open, 'Open'),
    (PreauthStatus.approved, 'Approved'),
    (PreauthStatus.rejected, 'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (status, label) in _options) ...[
              _FilterChip(
                label: label,
                selected: selected == status,
                onTap: () => onChanged(status),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kRadiusFull),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kPrimary : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent (≤14d, decided) vs History
// ─────────────────────────────────────────────────────────────────────────────

class _PreauthSections extends StatelessWidget {
  final List<Preauth> items;
  const _PreauthSections({required this.items});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recent = <Preauth>[];
    final history = <Preauth>[];
    for (final p in items) {
      if (p.isRecent(now: now)) {
        recent.add(p);
      } else {
        history.add(p);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (recent.isNotEmpty) ...[
          const _SectionHeader(
            label: 'Recent decisions',
            sub: 'Approved or rejected in the last 14 days',
          ),
          for (final p in recent) _PreauthCard(preauth: p, highlight: true),
          const SizedBox(height: 16),
        ],
        if (history.isNotEmpty) ...[
          _SectionHeader(
            label: recent.isEmpty ? 'Requests' : 'History',
            sub: recent.isEmpty
                ? 'All your pre-authorisation requests'
                : 'Earlier pre-authorisation requests',
          ),
          for (final p in history) _PreauthCard(preauth: p),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String sub;
  const _SectionHeader({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: kSubtext, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _PreauthCard extends StatelessWidget {
  final Preauth preauth;
  final bool highlight;
  const _PreauthCard({required this.preauth, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = preauthStatusColor(preauth.status);
    final hasService = preauth.description.isNotEmpty;
    final title = hasService
        ? preauth.description
        : (preauth.diagnosis.isNotEmpty
            ? preauth.diagnosis
            : 'Request ${preauth.claimNo}');

    return GestureDetector(
      onTap: () => context.push(
        '$routePreauths/${Uri.encodeComponent(preauth.id)}',
        extra: preauth,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kCardShadow,
          border: highlight
              ? Border.all(color: color.withValues(alpha: 0.45), width: 1.2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ),
                _StatusPill(status: preauth.status, label: preauth.statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              preauth.claimNo,
              style: const TextStyle(
                fontSize: 11.5,
                color: kSubtext,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            if (preauth.diagnosis.isNotEmpty && hasService) ...[
              const SizedBox(height: 4),
              Text(
                preauth.diagnosis,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: kSubtext),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (preauth.requestType.isNotEmpty)
                  _Chip(label: _typeLabel(preauth.requestType)),
                if (preauth.requestType.isNotEmpty) const SizedBox(width: 6),
                if (preauth.approvedAmount > 0)
                  _AmountBadge(
                    label: 'Approved',
                    amount: preauth.approvedAmount,
                    color: kSuccess,
                  )
                else if (preauth.requestedAmount > 0)
                  _AmountBadge(
                    label: 'Requested',
                    amount: preauth.requestedAmount,
                    color: kSubtext,
                  ),
                const Spacer(),
                if (preauth.requestDate != null)
                  Text(
                    highlight
                        ? DateFormat('dd MMM • HH:mm')
                            .format(preauth.requestDate!)
                        : DateFormat('dd MMM yyyy').format(preauth.requestDate!),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: highlight ? color : kTextLight,
                      fontWeight:
                          highlight ? FontWeight.w700 : FontWeight.w500,
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

class _StatusPill extends StatelessWidget {
  final PreauthStatus status;
  final String label;
  const _StatusPill({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = preauthStatusColor(status);
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
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusFull),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: kPrimary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AmountBadge extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountBadge({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Money(
          amount: amount,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Color preauthStatusColor(PreauthStatus s) {
  switch (s) {
    case PreauthStatus.approved:
      return kSuccess;
    case PreauthStatus.rejected:
      return kError;
    case PreauthStatus.cancelled:
      return kSubtext;
    case PreauthStatus.open:
    case PreauthStatus.unknown:
      return kAccentAmber;
  }
}

String _typeLabel(String raw) {
  final u = raw.toUpperCase();
  if (u.contains('DENTAL')) return 'DENTAL';
  if (u.contains('OPTICAL')) return 'OPTICAL';
  if (u.contains('OUT')) return 'OUTPATIENT';
  if (u.contains('IN')) return 'INPATIENT';
  return u;
}
