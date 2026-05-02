import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../../core/constants.dart';
import '../../providers/lifestyle_provider.dart';
import '../../models/lifestyle_partner.dart';
import 'partner_detail_screen.dart';

class PartnerLocatorScreen extends ConsumerStatefulWidget {
  const PartnerLocatorScreen({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<PartnerLocatorScreen> createState() =>
      _PartnerLocatorScreenState();
}

class _PartnerLocatorScreenState extends ConsumerState<PartnerLocatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    
    // Determine initial tab based on type parameter
    int initialIndex = 0;
    PartnerType initialPartnerType = PartnerType.gym;
    
    if (widget.initialType != null) {
      switch (widget.initialType!.toLowerCase()) {
        case 'nutritionist':
          initialIndex = 1;
          initialPartnerType = PartnerType.nutritionist;
          break;
        case 'counsellor':
        case 'counselor':
          initialIndex = 2;
          initialPartnerType = PartnerType.counsellor;
          break;
        default:
          initialIndex = 0;
          initialPartnerType = PartnerType.gym;
      }
    }
    
    _tabs = TabController(length: 3, initialIndex: initialIndex, vsync: this);
    _tabs.addListener(_onTabChanged);
    // Safe in ConsumerStatefulWidget — ref is available in initState
    ref.read(lifestyleProvider.notifier).fetchPartners(type: initialPartnerType);
    // Get location in background for distance sorting
    _tryGetLocation();
  }

  Future<void> _tryGetLocation() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return; // location not available — already loaded without sort
    }
    if (!mounted) return;
    setState(() => _userPos = pos);
    ref.read(lifestyleProvider.notifier).fetchPartners(
          type: PartnerType.gym,
          userLat: pos.latitude,
          userLng: pos.longitude,
        );
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) return;
    final types = [
      PartnerType.gym,
      PartnerType.nutritionist,
      PartnerType.counsellor,
    ];
    ref.read(lifestyleProvider.notifier).fetchPartners(
          type: types[_tabs.index],
          userLat: _userPos?.latitude,
          userLng: _userPos?.longitude,
        );
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Partners'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kPrimary,
          labelColor: kPrimary,
          tabs: const [
            Tab(text: 'Gyms'),
            Tab(text: 'Nutritionists'),
            Tab(text: 'Counsellors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildGymsGrid(
            state.partners.where((p) => p.type == PartnerType.gym).toList(),
            isLoading: state.isPartnersLoading,
            error: state.partnersError,
          ),
          _PartnerList(
            partners: state.partners
                .where((p) => p.type == PartnerType.nutritionist)
                .toList(),
            isLoading: state.isPartnersLoading,
            error: state.partnersError,
            onRetry: () => ref.read(lifestyleProvider.notifier).fetchPartners(
                  type: PartnerType.nutritionist,
                  userLat: _userPos?.latitude,
                  userLng: _userPos?.longitude,
                ),
          ),
          _PartnerList(
            partners: state.partners
                .where((p) => p.type == PartnerType.counsellor)
                .toList(),
            isLoading: state.isPartnersLoading,
            error: state.partnersError,
            onRetry: () => ref.read(lifestyleProvider.notifier).fetchPartners(
                  type: PartnerType.counsellor,
                  userLat: _userPos?.latitude,
                  userLng: _userPos?.longitude,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymsGrid(List<LifestylePartner> gyms,
      {bool isLoading = false, String? error}) {
    return Container(
      color: const Color(0xFFF2F2F2),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: const [
                  Icon(Icons.location_pin, color: kPrimary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Gyms Near You',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 46, bottom: 12),
              child: Text(
                'Sorted by distance',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ),
          ),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            )
          else if (error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Color(0xFFCBD5E1), size: 64),
                      const SizedBox(height: 16),
                      Text(error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kSubtext, fontSize: 15)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(lifestyleProvider.notifier).fetchPartners(
                                  type: PartnerType.gym,
                                  userLat: _userPos?.latitude,
                                  userLng: _userPos?.longitude,
                                ),
                        icon: const Icon(Icons.refresh, color: kPrimary),
                        label: const Text('Retry',
                            style: TextStyle(color: kPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (gyms.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off_outlined,
                        color: Color(0xFFCBD5E1), size: 64),
                    SizedBox(height: 16),
                    Text('No gyms found in your area',
                        style:
                            TextStyle(color: kSubtext, fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _GymLogoTile(
                    partner: gyms[i],
                    userPos: _userPos,
                  ),
                  childCount: gyms.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Gym logo tile ────────────────────────────────────────────────────────────

class _GymLogoTile extends StatelessWidget {
  final LifestylePartner partner;
  final Position? userPos;

  const _GymLogoTile({required this.partner, required this.userPos});

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return kPrimary;
    }
  }

  String get _initials {
    final words = partner.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  String get _distanceText {
    if (userPos == null ||
        partner.latitude == null ||
        partner.longitude == null) {
      return '';
    }
    final km = _haversineKm(
      userPos!.latitude,
      userPos!.longitude,
      partner.latitude!,
      partner.longitude!,
    );
    return '${km.toStringAsFixed(1)} km';
  }

  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
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

  @override
  Widget build(BuildContext context) {
    final logoColor = _parseColor(partner.logoColor);
    final distanceText = _distanceText;

    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PartnerDetailScreen(partner: partner),
          )),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: logoColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: logoColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          partner.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        Text(
          distanceText,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
        ),
      ],
    );
  }
}

// ── Partner list (Nutritionists / Counsellors) ───────────────────────────────

class _PartnerList extends StatelessWidget {
  final List<LifestylePartner> partners;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const _PartnerList({
    required this.partners,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  Future<void> _call(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWebsite(String? website) async {
    if (website == null) return;
    final uri = Uri.parse(website);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFCBD5E1), size: 64),
              const SizedBox(height: 16),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kSubtext, fontSize: 15)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, color: kPrimary),
                  label:
                      const Text('Retry', style: TextStyle(color: kPrimary)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (partners.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined,
                color: Color(0xFFCBD5E1), size: 64),
            SizedBox(height: 16),
            Text(
              'No partners found in your area',
              style: TextStyle(color: kSubtext, fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              'Try switching to map view or check back later.',
              style: TextStyle(color: kSubtext, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: partners.length,
      itemBuilder: (context, i) {
        final p = partners[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PartnerDetailScreen(partner: p),
              )),
              child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.typeLabel,
                        style: const TextStyle(
                            color: kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    if (p.phone != null)
                      GestureDetector(
                        onTap: () => _call(p.phone),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kSuccess.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone,
                              color: kSuccess, size: 16),
                        ),
                      ),
                    if (p.website != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openWebsite(p.website),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.open_in_new,
                              color: kPrimary, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: kSubtext),
                    const SizedBox(width: 4),
                    Text(
                      '${p.city}, ${p.province}',
                      style:
                          const TextStyle(fontSize: 12, color: kSubtext),
                    ),
                  ],
                ),
                if (p.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.address!,
                    style: const TextStyle(fontSize: 12, color: kSubtext),
                  ),
                ],
                if (p.phone != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _call(p.phone),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 13, color: kPrimary),
                        const SizedBox(width: 4),
                        Text(
                          p.phone!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: kPrimary,
                              decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }
}
