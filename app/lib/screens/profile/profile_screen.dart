import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/medications_provider.dart';
import '../../providers/lab_tests_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../services/biometric_service.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _exportingPdf = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  Future<void> _checkBiometrics() async {
    final available = await biometricService.isAvailable();
    final enabled = await biometricService.isEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Check if the device has biometrics enrolled first
      if (!_biometricAvailable) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.fingerprint, color: kPrimary, size: 26),
              SizedBox(width: 10),
              Text('No Fingerprint Enrolled'),
            ]),
            content: const Text(
              'Your phone has no fingerprint enrolled.\n\n'
              'To use biometric login, please go to:\n'
              'Settings → Security → Fingerprint\n\n'
              'Enroll your fingerprint there, then come back here to enable it.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }
      final creds = await biometricService.getCredentials();
      if (creds != null) {
        // Credentials already cached — just authenticate and re-enable
        final authed = await biometricService.authenticate();
        if (!authed || !mounted) return;
        await biometricService.saveCredentials(creds.memberNumber, creds.password);
        if (mounted) setState(() => _biometricEnabled = true);
      } else {
        // No credentials cached — ask for password to enroll
        if (!mounted) return;
        final member = ref.read(authProvider).member;
        if (member == null) return;
        await _showBiometricEnrollDialog(member.memberNumber);
      }
    } else {
      await biometricService.disable();
      if (mounted) setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _showBiometricEnrollDialog(String memberNumber) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.fingerprint, color: kPrimary, size: 26),
            SizedBox(width: 10),
            Text('Enable Biometric Login'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your password once to enroll biometric login.', style: TextStyle(fontSize: 13, color: kSubtext)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
              onPressed: () => Navigator.pop(ctx, passwordCtrl.text),
              child: const Text('Enable', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    passwordCtrl.dispose();
    if (confirmed == null || confirmed.isEmpty || !mounted) return;

    // Verify password and save credentials
    try {
      await ref.read(authProvider.notifier).loginWithMemberNumber(memberNumber, confirmed);
      // If login succeeded (no exception), biometric enrollment is valid
      final authed = await biometricService.authenticate();
      if (!authed || !mounted) return;
      await biometricService.saveCredentials(memberNumber, confirmed);
      if (mounted) setState(() => _biometricEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login enabled ✓'), backgroundColor: kPrimary),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password. Please try again.'), backgroundColor: kError),
        );
      }
    }
  }

  Future<void> _exportHealthReport(Member member) async {
    setState(() => _exportingPdf = true);
    try {
      final vitals = ref.read(vitalsProvider).vitals;
      final medications = ref.read(medicationsProvider).medications;
      final labTests = ref.read(labTestsProvider).tests;
      await PdfService.exportHealthReport(
        member: member,
        vitals: vitals,
        medications: medications,
        labTests: labTests,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: kError),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    // Fetch fresh profile data from DB (JWT doesn't include phone/email)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(memberProvider.notifier).fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final memberState = ref.watch(memberProvider);
    // Prefer fresh DB data; fall back to JWT-decoded member
    final member = memberState.member ?? authState.member;

    if (memberState.isLoading && memberState.member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingListCard(count: 4),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary, Color(0xFF0052CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        member?.initials ?? '?',
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member?.fullName ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member?.memberNumber ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      member?.planType ?? 'Standard',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoCard(member),
                  const SizedBox(height: 16),
                  _menuCard(context, member),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Member? member) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.badge_outlined, 'Member Number',
              member?.memberNumber ?? '—'),
          const Divider(height: 1),
          _infoRow(Icons.cake_outlined, 'Date of Birth',
              member?.dateOfBirth ?? '—'),
          const Divider(height: 1),
          _infoRow(Icons.email_outlined, 'Email',
              member?.email ?? 'Not set'),
          const Divider(height: 1),
          _infoRow(Icons.phone_outlined, 'Phone',
              member?.phone ?? 'Not set'),
          const Divider(height: 1),
          // Conditions row — always visible, tappable to edit
          InkWell(
            onTap: () => _showEditConditionsSheet(context, member),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_hospital_outlined,
                      size: 18, color: kPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Conditions',
                            style: TextStyle(fontSize: 11, color: kSubtext)),
                        const SizedBox(height: 6),
                        if (member?.conditions.isNotEmpty == true)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final c in List<String>.from(member!.conditions))
                                Chip(
                                  label: Text(c),
                                  backgroundColor: kPrimary.withValues(alpha: 0.08),
                                  labelStyle: const TextStyle(
                                      color: kPrimary, fontSize: 12),
                                ),
                            ],
                          )
                        else
                          const Text('Tap to add your conditions',
                              style: TextStyle(fontSize: 13, color: kSubtext)),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: kSubtext),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: kSubtext)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: kText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, Member? member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Care Management ────────────────────────────────────────
        _sectionLabel('Care Management'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              _menuItem(context, Icons.medical_information_outlined,
                  'Treatment Plans',
                  onTap: () => context.push(routeTreatment)),
              const Divider(height: 1),
              _menuItem(context, Icons.science_outlined, 'Lab Results',
                  onTap: () => context.push(routeLabResults)),
              const Divider(height: 1),
              _menuItem(context, Icons.local_hospital_outlined,
                  'My Care Provider',
                  onTap: () => context.push(routeMyProvider)),
              const Divider(height: 1),
              _menuItem(context, Icons.assignment_outlined,
                  'Pre-Authorization Requests',
                  onTap: () => context.push('/authorizations')),
              const Divider(height: 1),
              _menuItem(
                context,
                Icons.picture_as_pdf_outlined,
                'Export Health Report',
                subtitle: 'Download or share a PDF summary',
                loading: _exportingPdf,
                onTap: member == null || _exportingPdf
                    ? null
                    : () => _exportHealthReport(member),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Account ────────────────────────────────────────────────
        _sectionLabel('Account'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              _menuItem(context, Icons.edit_outlined, 'Edit Contact Info',
                  onTap: () => _showEditDialog(context)),
              const Divider(height: 1),
              _menuItem(context, Icons.lock_outline, 'Change Password',
                  onTap: () => context.push(routeChangePassword)),
              const Divider(height: 1),
              _biometricToggleItem(),
              const Divider(height: 1),
              _menuItem(context, Icons.notifications_outlined,
                  'Notification Preferences',
                  onTap: () => context.push(routeSettings)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Legal & Info ───────────────────────────────────────────
        _sectionLabel('Legal & Info'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              _menuItem(context, Icons.privacy_tip_outlined,
                  'Privacy & Consent',
                  onTap: () => _showPrivacyDialog(context)),
              const Divider(height: 1),
              _menuItem(
                context,
                Icons.info_outline,
                'About',
                subtitle: 'Sanlam Chronic Care v1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Sanlam Chronic Care',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 Sanlam Allianz Life Insurance',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Sign Out ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8),
            ],
          ),
          child: _menuItem(
            context,
            Icons.logout_outlined,
            'Sign Out',
            color: kError,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Sign Out'),
                  content:
                      const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: kError),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _biometricToggleItem() {
    final unavailable = !_biometricAvailable;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.fingerprint,
              color: unavailable ? Colors.grey : kPrimary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Biometric Login',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: unavailable ? Colors.grey : kText)),
                Text(
                  unavailable
                      ? 'No fingerprint enrolled on this device'
                      : _biometricEnabled
                          ? 'Enabled — tap to disable'
                          : 'Enable fingerprint / Face ID login',
                  style: TextStyle(
                      fontSize: 11,
                      color: unavailable ? Colors.grey : kSubtext),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _biometricEnabled,
            activeColor: kPrimary,
            onChanged: _toggleBiometric,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kSubtext,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String label, {
    String? subtitle,
    Color? color,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? kPrimary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color ?? kText,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: kSubtext),
                    ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
              )
            else
              Icon(Icons.chevron_right,
                  color: color ?? kSubtext, size: 18),
          ],
        ),
      ),
    );
  }

  void _showEditConditionsSheet(BuildContext context, Member? member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditConditionsSheet(
        ref: ref,
        initialConditions: List<String>.from(member?.conditions ?? []),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditContactDialog(ref: ref),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy & Consent'),
        content: const SingleChildScrollView(
          child: Text(
            'Sanlam collects and processes your health data to provide personalised chronic care management services. '
            'Your data is encrypted and stored securely in accordance with POPIA (Protection of Personal Information Act).\n\n'
            'We will never sell your data to third parties. You may request deletion of your data by contacting '
            'sancare@ug.sanlamallianz.com.\n\n'
            'By using this app, you consent to the processing of your health information as described in our Privacy Policy.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _EditContactDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _EditContactDialog({required this.ref});

  @override
  ConsumerState<_EditContactDialog> createState() =>
      _EditContactDialogState();
}

class _EditContactDialogState extends ConsumerState<_EditContactDialog> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final member = widget.ref.read(memberProvider).member ??
        widget.ref.read(authProvider).member;
    _phoneCtrl = TextEditingController(text: member?.phone ?? '');
    _emailCtrl = TextEditingController(text: member?.email ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await ref.read(memberProvider.notifier).updateContact(
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      // Sync the updated member back to authProvider so the profile card refreshes
      final updated = ref.read(memberProvider).member;
      if (updated != null) {
        ref.read(authProvider.notifier).updateMember(updated);
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact info updated!'),
          backgroundColor: kSuccess,
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = ref.read(memberProvider).error ?? 'Failed to update. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Contact Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            label: 'Phone',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined, color: kSubtext),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, color: kSubtext),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: kError, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Edit Conditions Bottom Sheet ───────────────────────────────────────────

class _EditConditionsSheet extends StatefulWidget {
  final WidgetRef ref;
  final List<String> initialConditions;

  const _EditConditionsSheet({
    required this.ref,
    required this.initialConditions,
  });

  @override
  State<_EditConditionsSheet> createState() => _EditConditionsSheetState();
}

class _EditConditionsSheetState extends State<_EditConditionsSheet> {
  late List<String> _selected;
  final _searchCtrl = TextEditingController();
  List<String> _catalog = [];
  List<String> _suggestions = [];
  bool _loadingCatalog = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialConditions);
    _fetchCatalog();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalog() async {
    try {
      final response = await dio.get('/conditions');
      final data = jsonDecode(jsonEncode(response.data)) as List;
      setState(() {
        _catalog = data
            .map<String>((c) => (c is Map ? c['name'] : c).toString())
            .where((s) => s.isNotEmpty)
            .toList();
        _loadingCatalog = false;
      });
    } catch (_) {
      setState(() => _loadingCatalog = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final filtered = _catalog
        .where((c) => c.toLowerCase().contains(q))
        .where((c) => !_selected.contains(c))
        .take(6)
        .toList();
    setState(() => _suggestions = filtered);
  }

  void _addCondition(String name) {
    final clean = name.trim();
    if (clean.isEmpty || _selected.contains(clean)) return;
    setState(() {
      _selected.add(clean);
      _searchCtrl.clear();
      _suggestions = [];
    });
  }

  void _removeCondition(String name) {
    setState(() => _selected.remove(name));
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final success = await widget.ref
        .read(memberProvider.notifier)
        .updateConditions(_selected);
    if (!mounted) return;
    if (success) {
      final updated = widget.ref.read(memberProvider).member;
      if (updated != null) {
        widget.ref.read(authProvider.notifier).updateMember(updated);
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conditions updated!'),
          backgroundColor: kSuccess,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = widget.ref.read(memberProvider).error ?? 'Failed to save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final showAddCustom = query.isNotEmpty &&
        !_selected.contains(query) &&
        !_catalog.any((c) => c.toLowerCase() == query.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Manage Conditions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Selected conditions chips
                  if (_selected.isNotEmpty) ...[
                    const Text('Your conditions',
                        style: TextStyle(fontSize: 12, color: kSubtext, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final c in _selected)
                          Chip(
                            label: Text(c,
                                style: const TextStyle(
                                    fontSize: 13, color: kPrimary)),
                            backgroundColor: kPrimary.withValues(alpha: 0.08),
                            deleteIcon: const Icon(Icons.close,
                                size: 16, color: kPrimary),
                            onDeleted: () => _removeCondition(c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Search field
                  const Text('Search or add condition',
                      style: TextStyle(fontSize: 12, color: kSubtext, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: _loadingCatalog
                          ? 'Loading catalog…'
                          : 'Type to search (e.g. Diabetes)',
                      prefixIcon: const Icon(Icons.search, color: kSubtext, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _suggestions = []);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  // Suggestions list
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < _suggestions.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.add_circle_outline,
                                  color: kPrimary, size: 20),
                              title: Text(_suggestions[i],
                                  style: const TextStyle(fontSize: 14)),
                              onTap: () => _addCondition(_suggestions[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // "Add custom" option when no catalog match
                  if (showAddCustom) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _addCondition(query),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: kAccent),
                          borderRadius: BorderRadius.circular(10),
                          color: kAccent.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add, color: kAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Add "$query"',
                                style: const TextStyle(
                                    color: kAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: kError, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Conditions',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
