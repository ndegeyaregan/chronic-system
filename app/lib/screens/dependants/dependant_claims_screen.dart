import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../models/visit.dart';
import '../../providers/visits_provider.dart';
import '../../utils/benefit_forecast.dart';
import '../claims/claims_screen.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/visit_tile.dart';

class DependantClaimsScreen extends ConsumerStatefulWidget {
  final String memberNo;
  final String dependantName;

  const DependantClaimsScreen({
    super.key,
    required this.memberNo,
    required this.dependantName,
  });

  @override
  ConsumerState<DependantClaimsScreen> createState() =>
      _DependantClaimsScreenState();
}

class _DependantClaimsScreenState
    extends ConsumerState<DependantClaimsScreen> {
  ClaimCategory _filter = ClaimCategory.all;

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitsByMemberProvider(widget.memberNo));

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claims',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            Text(
              widget.dependantName,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: _FilterBar(
            selected: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
      ),
      body: visitsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [LoadingListCard(count: 6)],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Failed to load claims',
          subtitle: e.toString(),
          buttonLabel: 'Retry',
          onButton: () =>
              ref.invalidate(visitsByMemberProvider(widget.memberNo)),
        ),
        data: (visits) {
          final filtered =
              visits.where((v) => _filter.matches(v.treatmentType)).toList();

          if (filtered.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: _filter == ClaimCategory.all
                      ? 'No claims found'
                      : 'No ${_filter.label.toLowerCase()} claims',
                  subtitle: _filter == ClaimCategory.all
                      ? 'No claims have been processed for ${widget.dependantName} yet.'
                      : 'Try a different category.',
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(visitsByMemberProvider(widget.memberNo)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, i) => VisitTile(
                visit: filtered[i],
                onTap: () => context.push(
                  '$routeClaims/${filtered[i].visitId}',
                  extra: {
                    'visit': filtered[i],
                    'memberNo': widget.memberNo,
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ClaimCategory selected;
  final ValueChanged<ClaimCategory> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in ClaimCategory.values) ...[
              _Chip(
                label: c.label,
                selected: selected == c,
                onTap: () => onChanged(c),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kRadiusFull),
          border: Border.all(
            color:
                Colors.white.withValues(alpha: selected ? 1 : 0.35),
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
