import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/prescription.dart';
import '../../providers/prescriptions_provider.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';

/// Filter chips for the prescriptions list.
enum _StatusFilter { all, pending, partial, issued }

extension on _StatusFilter {
  String get label {
    switch (this) {
      case _StatusFilter.all:
        return 'All';
      case _StatusFilter.pending:
        return 'Pending';
      case _StatusFilter.partial:
        return 'Partial';
      case _StatusFilter.issued:
        return 'Issued';
    }
  }
}

final _statusFilterProvider =
    StateProvider<_StatusFilter>((_) => _StatusFilter.all);

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  late final TextEditingController _claimCtrl;

  @override
  void initState() {
    super.initState();
    _claimCtrl = TextEditingController(
      text: ref.read(prescriptionsClaimFilterProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _claimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claimFilter = ref.watch(prescriptionsClaimFilterProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final async = ref.watch(prescriptionsProvider(claimFilter));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'My Prescriptions',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              _ClaimSearchBar(
                controller: _claimCtrl,
                onSubmit: (v) {
                  final trimmed = v.trim();
                  ref.read(prescriptionsClaimFilterProvider.notifier).state =
                      trimmed.isEmpty ? null : trimmed;
                },
                onClear: () {
                  _claimCtrl.clear();
                  ref.read(prescriptionsClaimFilterProvider.notifier).state =
                      null;
                },
              ),
              _StatusChips(
                selected: statusFilter,
                onChanged: (v) =>
                    ref.read(_statusFilterProvider.notifier).state = v,
              ),
            ],
          ),
        ),
      ),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [LoadingListCard(count: 4)],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.medication_outlined,
          title: 'Failed to load prescriptions',
          subtitle: e.toString(),
          buttonLabel: 'Retry',
          onButton: () => ref.invalidate(prescriptionsProvider(claimFilter)),
        ),
        data: (items) {
          final filtered = _applyStatusFilter(items, statusFilter);
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(prescriptionsProvider(claimFilter)),
            child: filtered.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.12),
                      EmptyState(
                        icon: Icons.medication_outlined,
                        title: claimFilter != null
                            ? 'No prescriptions for $claimFilter'
                            : 'No prescriptions yet',
                        subtitle:
                            'Prescriptions sent to your pharmacy by your doctor will appear here.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _PrescriptionCard(prescription: filtered[i]),
                  ),
          );
        },
      ),
    );
  }

  List<Prescription> _applyStatusFilter(
      List<Prescription> items, _StatusFilter f) {
    switch (f) {
      case _StatusFilter.all:
        return items;
      case _StatusFilter.pending:
        return items.where((p) => p.isPending).toList();
      case _StatusFilter.partial:
        return items.where((p) => p.isPartiallyIssued).toList();
      case _StatusFilter.issued:
        return items.where((p) => p.isFullyIssued).toList();
    }
  }
}

class _ClaimSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  const _ClaimSearchBar({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        style: const TextStyle(fontSize: 14, color: kText),
        decoration: InputDecoration(
          hintText: 'Filter by claim no. (e.g. PRHE-260428-347)',
          hintStyle: const TextStyle(fontSize: 13, color: kTextLight),
          prefixIcon: const Icon(Icons.search, color: kSubtext, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: kSubtext),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final _StatusFilter selected;
  final ValueChanged<_StatusFilter> onChanged;

  const _StatusChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _StatusFilter.values.map((f) {
          final isSel = f == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(f.label),
              selected: isSel,
              onSelected: (_) => onChanged(f),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : kPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              backgroundColor: Colors.white,
              selectedColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusFull),
                side: BorderSide(
                    color: isSel ? kPrimary : kBorder, width: 1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final color = _statusColor(p);
    final statusLabel = _statusLabel(p);

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Icon(Icons.medication_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.medication.isEmpty ? '—' : p.medication,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kText,
                      ),
                    ),
                    if (p.code.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.code,
                          style:
                              const TextStyle(fontSize: 11, color: kSubtext),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusFull),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.dosage.isNotEmpty) _row(Icons.schedule, 'Dosage', p.dosage),
          _row(Icons.confirmation_number_outlined, 'Quantity',
              '${p.issuedQty} / ${p.qty} issued'),
          if (p.prescribedBy.isNotEmpty)
            _row(Icons.person_outline, 'Prescribed by', p.prescribedBy),
          _claimRow(context, p),
          if (p.issuedClaimNo.isNotEmpty)
            _row(Icons.receipt_outlined, 'Issued claim', p.issuedClaimNo),
          if (p.category.isNotEmpty)
            _row(Icons.category_outlined, 'Category', p.category),
        ],
      ),
    );
  }

  static Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kSubtext),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: kSubtext, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, color: kText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimRow(BuildContext context, Prescription p) {
    if (p.claimNo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tag, size: 16, color: kSubtext),
          const SizedBox(width: 8),
          const Text('Claim: ',
              style: TextStyle(
                  fontSize: 12, color: kSubtext, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              p.claimNo,
              style: const TextStyle(
                  fontSize: 12, color: kText, fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: p.claimNo));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied ${p.claimNo}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.copy, size: 14, color: kSubtext),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(Prescription p) {
    if (p.isFullyIssued) return kSuccess;
    if (p.isPartiallyIssued) return kWarning;
    return kInfo;
  }

  static String _statusLabel(Prescription p) {
    if (p.isFullyIssued) return 'Issued';
    if (p.isPartiallyIssued) return 'Partial';
    return 'Pending';
  }
}
