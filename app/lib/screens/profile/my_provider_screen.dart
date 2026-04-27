import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/member_provider_info.dart';
import '../../models/member_provider.dart';
import '../../models/hospital.dart';
import '../../services/api_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class MyProviderScreen extends ConsumerStatefulWidget {
  const MyProviderScreen({super.key});

  @override
  ConsumerState<MyProviderScreen> createState() => _MyProviderScreenState();
}

class _MyProviderScreenState extends ConsumerState<MyProviderScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProviderInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Care Provider')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: kPrimary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your care provider will be notified about your health updates.',
                      style: TextStyle(fontSize: 12, color: kText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (state.isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator())),

            // Existing provider card
            if (!state.isLoading && state.provider != null && !_showForm) ...[
              _ProviderCard(
                provider: state.provider!,
                onEdit: () => setState(() => _showForm = true),
              ),
              const SizedBox(height: 16),
            ],

            // No provider yet — prompt to add
            if (!state.isLoading && state.provider == null && !_showForm) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.person_add_alt_1_outlined,
                          size: 48, color: kSubtext),
                      SizedBox(height: 12),
                      Text(
                        'No care provider added yet.',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kText),
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: 'Add Care Provider',
                onPressed: () => setState(() => _showForm = true),
                leadingIcon: Icons.add,
              ),
              const SizedBox(height: 16),
            ],

            // Form
            if (_showForm) ...[
              _ProviderForm(
                existing: state.provider,
                onCancel: () => setState(() => _showForm = false),
                onSaved: () => setState(() => _showForm = false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final MemberProvider provider;
  final VoidCallback onEdit;

  const _ProviderCard({required this.provider, required this.onEdit});

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _typeLabel(provider.providerType),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimary),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                      foregroundColor: kPrimary),
                ),
              ],
            ),
          ),
          // Doctor section
          if (provider.hasDoctor) ...[
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.medical_services_outlined,
                      color: kPrimary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Doctor',
                            style:
                                TextStyle(fontSize: 11, color: kSubtext)),
                        Text(
                          provider.doctorName ?? '—',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kText),
                        ),
                        if (provider.doctorContact != null)
                          Text(
                            provider.doctorContact!,
                            style: const TextStyle(
                                fontSize: 12, color: kSubtext),
                          ),
                        if (provider.doctorEmail != null)
                          Text(
                            provider.doctorEmail!,
                            style: const TextStyle(
                                fontSize: 12, color: kSubtext),
                          ),
                      ],
                    ),
                  ),
                  if (provider.doctorContact != null)
                    IconButton(
                      onPressed: () => _call(provider.doctorContact!),
                      icon: const Icon(Icons.call, color: kSuccess),
                      tooltip: 'Call doctor',
                    ),
                ],
              ),
            ),
          ],
          // Hospital section
          if (provider.hasHospital) ...[
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital_outlined,
                      color: kPrimary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hospital',
                            style:
                                TextStyle(fontSize: 11, color: kSubtext)),
                        Text(
                          provider.hospitalName ?? '—',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kText),
                        ),
                        if (provider.hospitalAddress != null)
                          Text(
                            provider.hospitalAddress!,
                            style: const TextStyle(
                                fontSize: 12, color: kSubtext),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (provider.notes != null) ...[
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                provider.notes!,
                style: const TextStyle(
                    fontSize: 12, color: kSubtext, height: 1.4),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'doctor':
        return 'Doctor';
      case 'hospital':
        return 'Hospital';
      case 'both':
        return 'Doctor & Hospital';
      default:
        return type;
    }
  }
}

class _ProviderForm extends ConsumerStatefulWidget {
  final MemberProvider? existing;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const _ProviderForm({
    this.existing,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  ConsumerState<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends ConsumerState<_ProviderForm> {
  final _formKey = GlobalKey<FormState>();
  String _providerType = 'doctor';
  final _doctorNameCtrl = TextEditingController();
  final _doctorContactCtrl = TextEditingController();
  final _doctorEmailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Hospital? _selectedHospital;

  bool get _showDoctor =>
      _providerType == 'doctor' || _providerType == 'both';
  bool get _showHospital =>
      _providerType == 'hospital' || _providerType == 'both';

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _providerType = p.providerType;
      _doctorNameCtrl.text = p.doctorName ?? '';
      _doctorContactCtrl.text = p.doctorContact ?? '';
      _doctorEmailCtrl.text = p.doctorEmail ?? '';
      _notesCtrl.text = p.notes ?? '';
      if (p.hospitalId != null) {
        _selectedHospital = Hospital(
          id: p.hospitalId!,
          name: p.hospitalName ?? 'Unknown Hospital',
          city: '',
          province: '',
          address: p.hospitalAddress,
        );
      }
    }
  }

  @override
  void dispose() {
    _doctorNameCtrl.dispose();
    _doctorContactCtrl.dispose();
    _doctorEmailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_showHospital && _selectedHospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a hospital from the list'),
          backgroundColor: kError,
        ),
      );
      return;
    }

    final success =
        await ref.read(memberProviderInfoProvider.notifier).saveProvider(
              providerType: _providerType,
              doctorName: _showDoctor && _doctorNameCtrl.text.isNotEmpty
                  ? _doctorNameCtrl.text.trim()
                  : null,
              doctorContact:
                  _showDoctor && _doctorContactCtrl.text.isNotEmpty
                      ? _doctorContactCtrl.text.trim()
                      : null,
              doctorEmail:
                  _showDoctor && _doctorEmailCtrl.text.isNotEmpty
                      ? _doctorEmailCtrl.text.trim()
                      : null,
              hospitalId: _selectedHospital?.id,
              hospitalName: _selectedHospital?.name,
              hospitalAddress: _selectedHospital?.address,
              notes: _notesCtrl.text.isNotEmpty
                  ? _notesCtrl.text.trim()
                  : null,
            );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Care provider saved!'),
          backgroundColor: kSuccess,
        ),
      );
      widget.onSaved();
    } else if (mounted) {
      final err = ref.read(memberProviderInfoProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: kError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProviderInfoProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Provider Type',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: kText),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeChip(
                label: 'Doctor',
                selected: _providerType == 'doctor',
                onTap: () => setState(() => _providerType = 'doctor'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Hospital',
                selected: _providerType == 'hospital',
                onTap: () => setState(() => _providerType = 'hospital'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Both',
                selected: _providerType == 'both',
                onTap: () => setState(() => _providerType = 'both'),
              ),
            ],
          ),
          if (_showDoctor) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👨‍⚕️ Doctor',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kText),
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Doctor Name',
                    hint: 'e.g. Dr. Sarah Nakamura',
                    controller: _doctorNameCtrl,
                    prefixIcon: const Icon(Icons.person_outlined,
                        color: kSubtext),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Doctor Contact',
                    hint: 'e.g. +256 700 000 000',
                    controller: _doctorContactCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon:
                        const Icon(Icons.phone_outlined, color: kSubtext),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (_showDoctor &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Doctor contact is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Doctor Email (optional)',
                    hint: 'e.g. doctor@hospital.ug',
                    controller: _doctorEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: kSubtext),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
          if (_showHospital) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏥 Hospital',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kText),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a hospital added by your administrator',
                    style: TextStyle(fontSize: 11, color: kSubtext),
                  ),
                  const SizedBox(height: 12),
                  _HospitalSearchField(
                    selected: _selectedHospital,
                    onChanged: (h) => setState(() => _selectedHospital = h),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppInput(
            label: 'Notes (optional)',
            hint: 'Any additional notes about your provider...',
            controller: _notesCtrl,
            maxLines: 2,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 10),
            Text(
              state.error!,
              style: const TextStyle(color: kError, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: widget.existing != null
                ? 'Update Provider'
                : 'Save Provider',
            onPressed: _submit,
            isLoading: state.isLoading,
            leadingIcon: Icons.save_outlined,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Cancel',
            onPressed: widget.onCancel,
            variant: AppButtonVariant.outlined,
          ),
        ],
      ),
    );
  }
}

class _HospitalSearchField extends StatefulWidget {
  final Hospital? selected;
  final void Function(Hospital?) onChanged;

  const _HospitalSearchField({required this.onChanged, this.selected});

  @override
  State<_HospitalSearchField> createState() => _HospitalSearchFieldState();
}

class _HospitalSearchFieldState extends State<_HospitalSearchField> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Hospital> _all = [];
  List<Hospital> _filtered = [];
  bool _loading = true;
  bool _showResults = false;
  Hospital? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200),
            () { if (mounted) setState(() => _showResults = false); });
      }
    });
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    try {
      final response = await dio.get('/hospitals');
      if (mounted) {
        final list = (response.data as List)
            .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _all = list;
          _filtered = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((h) =>
                  h.name.toLowerCase().contains(q) ||
                  h.city.toLowerCase().contains(q) ||
                  h.province.toLowerCase().contains(q))
              .toList();
      _showResults = true;
    });
  }

  void _select(Hospital h) {
    setState(() {
      _selected = h;
      _showResults = false;
      _searchCtrl.clear();
    });
    _focusNode.unfocus();
    widget.onChanged(h);
  }

  void _clear() {
    setState(() {
      _selected = null;
      _searchCtrl.clear();
      _filtered = _all;
    });
    widget.onChanged(null);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _buildSelectedCard();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Search Hospital',
            hintText: 'Type hospital name or city...',
            prefixIcon: const Icon(Icons.search, color: kSubtext, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: _onSearch,
          onTap: () => setState(() {
            _showResults = true;
            _filtered = _all;
          }),
        ),
        if (_showResults) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
              boxShadow: kCardShadow,
            ),
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No hospitals found',
                        style: TextStyle(color: kSubtext, fontSize: 13)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final h = _filtered[i];
                      final subtitle = [
                        if (h.city.isNotEmpty) h.city,
                        if (h.province.isNotEmpty) h.province,
                        if (h.address != null && h.address!.isNotEmpty)
                          h.address!,
                      ].join(' • ');
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_hospital_outlined,
                            color: kPrimary, size: 18),
                        title: Text(h.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: kText)),
                        subtitle: subtitle.isNotEmpty
                            ? Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 11, color: kSubtext))
                            : null,
                        onTap: () => _select(h),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedCard() {
    final info = [
      if (_selected!.city.isNotEmpty) _selected!.city,
      if (_selected!.province.isNotEmpty) _selected!.province,
      if (_selected!.address != null && _selected!.address!.isNotEmpty)
        _selected!.address!,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: kPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selected!.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kText)),
                if (info.isNotEmpty)
                  Text(info,
                      style: const TextStyle(fontSize: 11, color: kSubtext)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kSubtext.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: kSubtext),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kPrimary : kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : kText,
          ),
        ),
      ),
    );
  }
}
