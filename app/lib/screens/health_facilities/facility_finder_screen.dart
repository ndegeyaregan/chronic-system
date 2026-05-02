import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/institution.dart';
import '../../providers/co_pays_provider.dart';
import '../../providers/institutions_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common/loading_shimmer.dart';
import 'institution_detail_screen.dart';

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

  void _showAddInstitutionDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Institution'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Institution Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'outpatient', child: Text('Outpatient')),
                    DropdownMenuItem(value: 'inpatient', child: Text('Inpatient')),
                    DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
                    DropdownMenuItem(value: 'dental', child: Text('Dental')),
                    DropdownMenuItem(value: 'optical', child: Text('Optical')),
                  ],
                  onChanged: (val) => setState(() => selectedCategory = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _createInstitution(
                context,
                nameCtrl.text,
                selectedCategory,
                phoneCtrl.text,
                emailCtrl.text,
                addressCtrl.text,
                cityCtrl.text,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInstitution(
    BuildContext context,
    String name,
    String? category,
    String phone,
    String email,
    String address,
    String city,
  ) async {
    if (name.isEmpty || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    try {
      Navigator.of(context).pop();
      await dio.post(
        'institutions',
        data: {
          'name': name,
          'category': category,
          'phone': phone.isEmpty ? null : phone,
          'email': email.isEmpty ? null : email,
          'address': address.isEmpty ? null : address,
          'city': city.isEmpty ? null : city,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institution added successfully')),
        );
        ref.read(institutionsProvider.notifier).fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
        actions: [
          IconButton(
            tooltip: 'Add Institution',
            onPressed: () => _showAddInstitutionDialog(context),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
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
                hintStyle: const TextStyle(color: kSubtext, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kSubtext, size: 20),
                suffixIcon: state.search.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          notifier.setSearch('');
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
            border: Border.all(color: selected ? kPrimary : kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: selected ? Colors.white : kSubtext),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : kText)),
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
      return _emptyState(
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
    final hasCoPay = coPay != null && coPay.hasAnyCharge;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InstitutionDetailScreen(institution: institution),
        ),
      ),
      child: Container(
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
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kText)),
                    if (cityLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(cityLine,
                          style: const TextStyle(fontSize: 12, color: kSubtext)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(InstitutionCategory.label(institution.category), color),
                  if (hasCoPay) ...[
                    const SizedBox(height: 4),
                    _badge('Co-pay', Colors.amber.shade800),
                  ],
                ],
              ),
            ],
          ),
          if (institution.contactName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: kSubtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(institution.contactName,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
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
                const Icon(Icons.location_on_outlined,
                    size: 13, color: kSubtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(institution.address!,
                      style: const TextStyle(fontSize: 12, color: kSubtext),
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

Widget _emptyState(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: kTextLight),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(
                fontSize: 14, color: kSubtext, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
