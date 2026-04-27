import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/hospitals_provider.dart';
import '../../providers/pharmacies_provider.dart';
import '../../models/hospital.dart';
import '../../models/pharmacy.dart';
import '../../widgets/common/loading_shimmer.dart';

class FacilityFinderScreen extends ConsumerStatefulWidget {
  const FacilityFinderScreen({super.key});

  @override
  ConsumerState<FacilityFinderScreen> createState() =>
      _FacilityFinderScreenState();
}

class _FacilityFinderScreenState extends ConsumerState<FacilityFinderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    setState(() => _searchText = val);
    if (_tabs.index == 0) {
      ref.read(hospitalsProvider.notifier).fetchHospitals(search: val.trim());
    } else {
      ref.read(pharmaciesProvider.notifier).fetchPharmacies(search: val.trim());
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospState = ref.watch(hospitalsProvider);
    final pharmState = ref.watch(pharmaciesProvider);

    return Scaffold(
      backgroundColor: kBg,
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
        title: const Text('Find a Facility',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          onTap: (_) {
            if (_searchText.isNotEmpty) _onSearch(_searchText);
          },
          tabs: const [
            Tab(text: 'Hospitals 🏥'),
            Tab(text: 'Pharmacies 💊'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: const TextStyle(color: kSubtext, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: kSubtext, size: 20),
                suffixIcon: _searchText.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: kSubtext, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  borderSide:
                      const BorderSide(color: kPrimary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _HospitalsTab(
                  state: hospState,
                  onCall: _call,
                  onRefresh: () => ref
                      .read(hospitalsProvider.notifier)
                      .fetchHospitals(search: _searchText),
                ),
                _PharmaciesTab(
                  state: pharmState,
                  onCall: _call,
                  onRefresh: () => ref
                      .read(pharmaciesProvider.notifier)
                      .fetchPharmacies(search: _searchText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOSPITALS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _HospitalsTab extends StatelessWidget {
  final HospitalsState state;
  final Future<void> Function(String?) onCall;
  final Future<void> Function() onRefresh;

  const _HospitalsTab({
    required this.state,
    required this.onCall,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.hospitals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingListCard(count: 4),
      );
    }

    if (state.hospitals.isEmpty) {
      return _emptyState('No hospitals found', Icons.local_hospital_outlined);
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: state.hospitals.length,
        itemBuilder: (ctx, i) =>
            _HospitalCard(hospital: state.hospitals[i], onCall: onCall),
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final Future<void> Function(String?) onCall;

  const _HospitalCard({required this.hospital, required this.onCall});

  String _typeLabel(List<String> specialties) {
    if (specialties.isEmpty) return 'General';
    final lower = specialties.map((s) => s.toLowerCase()).toList();
    if (lower.any((s) =>
        s.contains('specialist') ||
        s.contains('cardio') ||
        s.contains('oncol') ||
        s.contains('neuro'))) { return 'Specialist'; }
    if (lower.any((s) => s.contains('clinic'))) { return 'Clinic'; }
    return 'General';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Specialist':
        return kInfo;
      case 'Clinic':
        return kSuccess;
      default:
        return kPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabel(hospital.specialties);
    final typeColor = _typeColor(typeLabel);
    final chips = hospital.specialties.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hospital.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kText)),
                    const SizedBox(height: 2),
                    Text('${hospital.city}, ${hospital.province}',
                        style: const TextStyle(
                            fontSize: 12, color: kSubtext)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(typeLabel, typeColor),
                  if (hospital.hasDirectBooking) ...[
                    const SizedBox(height: 4),
                    _badge('Direct Booking', kInfo),
                  ],
                ],
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: chips
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(kRadiusFull),
                          border: Border.all(color: kBorder),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 10, color: kSubtext)),
                      ))
                  .toList(),
            ),
          ],
          if (hospital.address != null && hospital.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: kSubtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(hospital.address!,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (hospital.phone != null && hospital.phone!.isNotEmpty) ...[
                Expanded(
                  child: _outlineBtn(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: kSuccess,
                    onTap: () => onCall(hospital.phone),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (hospital.hasDirectBooking)
                Expanded(
                  child: _outlineBtn(
                    icon: Icons.calendar_today_rounded,
                    label: 'Book Appointment',
                    color: kPrimary,
                    onTap: () {},
                    filled: true,
                  ),
                ),
            ],
          ),
        ],
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHARMACIES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PharmaciesTab extends StatelessWidget {
  final PharmaciesState state;
  final Future<void> Function(String?) onCall;
  final Future<void> Function() onRefresh;

  const _PharmaciesTab({
    required this.state,
    required this.onCall,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.pharmacies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingListCard(count: 4),
      );
    }

    if (state.pharmacies.isEmpty) {
      return _emptyState('No pharmacies found', Icons.local_pharmacy_outlined);
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: state.pharmacies.length,
        itemBuilder: (ctx, i) =>
            _PharmacyCard(pharmacy: state.pharmacies[i], onCall: onCall),
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final Pharmacy pharmacy;
  final Future<void> Function(String?) onCall;

  const _PharmacyCard({required this.pharmacy, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child:
                const Icon(Icons.local_pharmacy_rounded, color: kSuccess, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(pharmacy.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kText)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusFull),
                      ),
                      child: const Text('Open',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: kSuccess)),
                    ),
                  ],
                ),
                if (pharmacy.address != null &&
                    pharmacy.address!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(pharmacy.address!,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (pharmacy.city != null && pharmacy.city!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(pharmacy.city!,
                      style: const TextStyle(fontSize: 12, color: kSubtext)),
                ],
                if (pharmacy.phone != null &&
                    pharmacy.phone!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => onCall(pharmacy.phone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: kSuccess.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        border: Border.all(
                            color: kSuccess.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 13, color: kSuccess),
                          const SizedBox(width: 5),
                          Text('Call ${pharmacy.phone}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kSuccess)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _emptyState(String message, IconData icon) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSubtext.withValues(alpha: 0.08),
            ),
            child: Icon(icon, color: kSubtext, size: 36),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kText),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('Try a different search term.',
              style: TextStyle(fontSize: 13, color: kSubtext),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
