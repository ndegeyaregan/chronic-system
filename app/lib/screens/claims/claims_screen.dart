import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/visits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/benefit_forecast.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/visit_tile.dart';

enum ClaimCategory { all, outpatient, inpatient, dental, optical }

extension on ClaimCategory {
  String get label {
    switch (this) {
      case ClaimCategory.all:
        return 'All';
      case ClaimCategory.outpatient:
        return 'Outpatient';
      case ClaimCategory.inpatient:
        return 'Inpatient';
      case ClaimCategory.dental:
        return 'Dental';
      case ClaimCategory.optical:
        return 'Optical';
    }
  }

  bool matches(String treatmentType) {
    switch (this) {
      case ClaimCategory.all:
        return true;
      case ClaimCategory.outpatient:
        return isOutPatient(treatmentType);
      case ClaimCategory.inpatient:
        return isInPatient(treatmentType);
      case ClaimCategory.dental:
        return isDental(treatmentType);
      case ClaimCategory.optical:
        return isOptical(treatmentType);
    }
  }
}

final claimCategoryFilterProvider =
    StateProvider<ClaimCategory>((_) => ClaimCategory.all);

class ClaimsScreen extends ConsumerWidget {
  const ClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).member;
    final visitsAsync = ref.watch(visitsProvider);
    final filter = ref.watch(claimCategoryFilterProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'My Claims',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: _CategoryFilterBar(
            selected: filter,
            onChanged: (v) =>
                ref.read(claimCategoryFilterProvider.notifier).state = v,
          ),
        ),
      ),
      body: visitsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [LoadingListCard(count: 5)],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Failed to load claims',
          subtitle: e.toString(),
          buttonLabel: 'Retry',
          onButton: () => ref.invalidate(visitsProvider),
        ),
        data: (visits) {
          final filtered =
              visits.where((v) => filter.matches(v.treatmentType)).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(visitsProvider),
            child: filtered.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.15),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: filter == ClaimCategory.all
                            ? 'No claims found'
                            : 'No ${filter.label.toLowerCase()} claims',
                        subtitle: filter == ClaimCategory.all
                            ? 'Your medical claims will appear here once processed.'
                            : 'Try a different category to see other claims.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => VisitTile(
                      visit: filtered[i],
                      onTap: () => context.push(
                        '$routeClaims/${filtered[i].visitId}',
                        extra: {
                          'visit': filtered[i],
                          'memberNo': member?.memberNumber ?? '',
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

class _CategoryFilterBar extends StatelessWidget {
  final ClaimCategory selected;
  final ValueChanged<ClaimCategory> onChanged;

  const _CategoryFilterBar(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in ClaimCategory.values) ...[
              _CategoryChip(
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
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
          color:
              selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
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
