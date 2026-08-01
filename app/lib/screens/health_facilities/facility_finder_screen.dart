import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/institution.dart';
import '../../providers/co_pays_provider.dart';
import '../../providers/institutions_provider.dart';
import '../../widgets/common/loading_shimmer.dart';
import 'institution_detail_screen.dart';
import '../../core/app_colors.dart';

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class FacilityFinderScreen extends ConsumerStatefulWidget {
  const FacilityFinderScreen({super.key});

  @override
  ConsumerState<FacilityFinderScreen> createState() =>
      _FacilityFinderScreenState();
}

class _FacilityFinderScreenState extends ConsumerState<FacilityFinderScreen> {
  final _searchCtrl = TextEditingController();

  static const _categoryIcons = <String, IconData>{
    InstitutionCategory.outpatient: Icons.medical_services_outlined,
    InstitutionCategory.inpatient:  Icons.local_hospital_outlined,
    InstitutionCategory.pharmacy:   Icons.local_pharmacy_outlined,
    InstitutionCategory.dental:     Icons.medication_liquid_outlined,
    InstitutionCategory.optical:    Icons.remove_red_eye_outlined,
  };

  @override
  void initState() {
    super.initState();
    _tryGetLocation();
  }

  Future<void> _tryGetLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      ref.read(institutionsProvider.notifier).setUserLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // Location unavailable or denied — list stays sorted alphabetically.
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(institutionsProvider);
    final notifier = ref.read(institutionsProvider.notifier);

    // Show one-shot snackbar after a manual sync.
    ref.listen<InstitutionsState>(institutionsProvider, (prev, next) {
      if (next.lastSyncMessage != null && next.lastSyncMessage != prev?.lastSyncMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.lastSyncMessage!)),
        );
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red.shade700),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
            ),
          ),
        ),
        title: Text('Find a Facility',
            style: TextStyle(
                color: context.c.cardBg,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sync from Sanlam',
            onPressed: state.isSyncing ? null : () => notifier.syncFromSanlam(),
            icon: state.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: notifier.setSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, city or address...',
                hintStyle: TextStyle(color: context.c.subtext, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: context.c.subtext, size: 20),
                suffixIcon: state.search.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          notifier.setSearch('');
                        },
                        child: Icon(Icons.close_rounded,
                            color: context.c.subtext, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide: BorderSide(color: context.c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide: BorderSide(color: context.c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide: const BorderSide(color: kPrimary, width: 1.5),
                ),
              ),
            ),
          ),
          // Category filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _CategoryChip(
                  label: 'All',
                  icon: Icons.apps_rounded,
                  selected: state.category == null,
                  onTap: () => notifier.setCategory(null),
                ),
                ...InstitutionCategory.all.map((c) => _CategoryChip(
                      label: InstitutionCategory.label(c),
                      icon: _categoryIcons[c] ?? Icons.business_rounded,
                      selected: state.category == c,
                      onTap: () => notifier.setCategory(c),
                    )),
              ],
            ),
          ),
          if (state.userLat != null && state.userLng != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.near_me_rounded, size: 13, color: context.c.subtext),
                  const SizedBox(width: 4),
                  Text('Sorted by distance',
                      style: TextStyle(fontSize: 12, color: context.c.subtext)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Expanded(child: _List(state: state, onCall: _call, onRefresh: notifier.fetch)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(kRadiusFull),
            border: Border.all(color: selected ? kPrimary : context.c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: selected ? Colors.white : context.c.subtext),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : context.c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final InstitutionsState state;
  final Future<void> Function(String?) onCall;
  final Future<void> Function() onRefresh;

  const _List({required this.state, required this.onCall, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingListCard(count: 5),
      );
    }
    if (state.items.isEmpty) {
      return _emptyState(context, 
        state.category == null
            ? 'No facilities found'
            : 'No ${InstitutionCategory.label(state.category!).toLowerCase()} facilities found',
        Icons.local_hospital_outlined,
      );
    }
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: state.items.length,
        itemBuilder: (ctx, i) =>
            _InstitutionCard(institution: state.items[i], onCall: onCall),
      ),
    );
  }
}

class _InstitutionCard extends ConsumerWidget {
  final Institution institution;
  final Future<void> Function(String?) onCall;

  const _InstitutionCard({required this.institution, required this.onCall});

  Color _categoryColor() {
    switch (institution.category) {
      case InstitutionCategory.pharmacy:   return kSuccess;
      case InstitutionCategory.inpatient:  return kPrimary;
      case InstitutionCategory.outpatient: return kInfo;
      case InstitutionCategory.dental:     return const Color(0xFF8B5CF6);
      case InstitutionCategory.optical:    return const Color(0xFFF59E0B);
      default: return kPrimary;
    }
  }

  IconData _categoryIcon() {
    switch (institution.category) {
      case InstitutionCategory.pharmacy:   return Icons.local_pharmacy_rounded;
      case InstitutionCategory.inpatient:  return Icons.local_hospital_rounded;
      case InstitutionCategory.outpatient: return Icons.medical_services_rounded;
      case InstitutionCategory.dental:     return Icons.medication_liquid_rounded;
      case InstitutionCategory.optical:    return Icons.remove_red_eye_rounded;
      default: return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _categoryColor();
    final cityLine = [institution.city, institution.province]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    final coPaysAsync = ref.watch(coPaysByInstIdProvider);
    final coPay = coPaysAsync.maybeWhen(
      data: (m) => institution.sanlamId != null ? m[institution.sanlamId!] : null,
      orElse: () => null,
    );
    final instCoPaysAsync = ref.watch(instCoPaysByInstIdProvider);
    final instCoPay = instCoPaysAsync.maybeWhen(
      data: (m) => institution.sanlamId != null ? m[institution.sanlamId!] : null,
      orElse: () => null,
    );
    final hasSchemeCoPay = coPay != null && coPay.hasAnyCharge;
    final hasInstCoPay = instCoPay != null && instCoPay.hasAnyCharge;
    final hasCoPay = hasSchemeCoPay || hasInstCoPay;

    final institutionsState = ref.watch(institutionsProvider);
    final userLat = institutionsState.userLat;
    final userLng = institutionsState.userLng;
    final distanceKm = (userLat != null &&
            userLng != null &&
            institution.latitude != null &&
            institution.longitude != null)
        ? _haversineKm(
            userLat, userLng, institution.latitude!, institution.longitude!)
        : null;

    return GestureDetector(
      onTap: institution.isSuspended
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      InstitutionDetailScreen(institution: institution),
                ),
              ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Icon(_categoryIcon(), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(institution.name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.c.text)),
                    if (cityLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(cityLine,
                          style: TextStyle(fontSize: 12, color: context.c.subtext)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(InstitutionCategory.label(institution.category), color),
                  if (distanceKm != null) ...[
                    const SizedBox(height: 4),
                    _badge('${distanceKm.toStringAsFixed(1)} km', kInfo),
                  ],
                  if (institution.isSuspended) ...[
                    const SizedBox(height: 4),
                    _badge('Suspended', Colors.red.shade700),
                  ],
                  if (hasCoPay) ...[
                    const SizedBox(height: 4),
                    _badge('Co-pay', Colors.amber.shade800),
                  ],
                ],
              ),
            ],
          ),
          if (institution.isSuspended &&
              institution.suspendedReason != null &&
              institution.suspendedReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Suspended: ${institution.suspendedReason!}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (institution.contactName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: context.c.subtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(institution.contactName,
                      style: TextStyle(fontSize: 12, color: context.c.subtext),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          if (institution.address != null && institution.address!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: context.c.subtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(institution.address!,
                      style: TextStyle(fontSize: 12, color: context.c.subtext),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          if (institution.phone != null && institution.phone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _outlineBtn(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: kSuccess,
                    onTap: () => onCall(institution.phone),
                  ),
                ),
                if (institution.email != null && institution.email!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _outlineBtn(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      color: kInfo,
                      onTap: () async {
                        final uri = Uri(scheme: 'mailto', path: institution.email);
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

Widget _emptyState(BuildContext context, String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: context.c.textLight),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(
                fontSize: 14, color: context.c.subtext, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
