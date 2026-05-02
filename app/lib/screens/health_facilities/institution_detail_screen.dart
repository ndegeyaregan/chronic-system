import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/institution.dart';
import '../../models/co_pay.dart';
import '../../providers/co_pays_provider.dart';
import '../../services/api_service.dart';

class InstitutionDetailScreen extends ConsumerWidget {
  final Institution institution;
  const InstitutionDetailScreen({super.key, required this.institution});

  String _money(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'UGX ${buf.toString()}';
  }

  Future<void> _openMaps() async {
    final hasCoords = institution.latitude != null && institution.longitude != null;
    final query = hasCoords
        ? '${institution.latitude},${institution.longitude}'
        : Uri.encodeComponent(
            [institution.name, institution.address, institution.city, institution.province]
                .where((s) => s != null && s.isNotEmpty)
                .join(', '),
          );
    // Universal Google Maps directions URL — works in browser & mobile maps app.
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(String addr) async {
    final uri = Uri(scheme: 'mailto', path: addr);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coPaysAsync = ref.watch(coPaysByInstIdProvider);

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
        title: const Text('Facility Details',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _header(),
          const SizedBox(height: 16),
          coPaysAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
            error: (e, _) => _coPayError(e.toString()),
            data: (map) {
              final key = institution.sanlamId ?? '';
              final cp = map[key];
              return _coPaySection(cp);
            },
          ),
          const SizedBox(height: 12),
          _contactCard(),
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
    );
  }

  Widget _header() {
    final cityLine = [institution.city, institution.province]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: kPrimary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(institution.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kText)),
                    if (cityLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(cityLine,
                          style: const TextStyle(fontSize: 12, color: kSubtext)),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusFull),
                      ),
                      child: Text(
                          InstitutionCategory.label(institution.category),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kPrimary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show suspension badge if suspended
          if (institution.isSuspended) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suspended${institution.suspendedReason != null ? ': ${institution.suspendedReason}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Show user-added badge
          if (institution.isUserAdded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add_rounded, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'User Added',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coPayError(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Could not load co-pay info: $msg',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
            ),
          ],
        ),
      );

  Widget _coPaySection(CoPay? cp) {
    if (cp == null || !cp.hasAnyCharge) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSuccess.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: kSuccess, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No co-pay required at this facility for your scheme.',
                style: TextStyle(
                    fontSize: 13, color: kText, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    void addRow(String label, double? amount, double? percent, double? max) {
      if ((amount == null || amount == 0) &&
          (percent == null || percent == 0)) return;
      final parts = <String>[];
      if (amount != null && amount > 0) parts.add(_money(amount));
      if (percent != null && percent > 0) {
        parts.add('${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}%');
      }
      if (max != null && max > 0) parts.add('max ${_money(max)}');
      rows.add(_coPayRow(label, parts.join(' + ')));
    }

    addRow('Out-Patient', cp.outPatient, cp.outPatientPercent, cp.outPatientMax);
    addRow('In-Patient',  cp.inPatient,  cp.inPatientPercent,  cp.inPatientMax);
    addRow('Dental',      cp.dental,     cp.dentalPercent,     null);
    addRow('Optical',     cp.optical,    cp.opticalPercent,    null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text('Your Co-Pay at this Facility',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900)),
            ],
          ),
          if ((cp.benefitSchemes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Applies to: ${cp.benefitSchemes}',
                style: const TextStyle(fontSize: 11, color: kSubtext)),
          ],
          const SizedBox(height: 12),
          ...rows,
          const SizedBox(height: 6),
          Text(
            'You pay this portion at the facility; the balance is covered by your scheme.',
            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
          ),
        ],
      ),
    );
  }

  Widget _coPayRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: kText, fontWeight: FontWeight.w500)),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, color: kText, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _contactCard() {
    final rows = <Widget>[];
    void add(IconData ic, String? v, {VoidCallback? onTap}) {
      if (v == null || v.isEmpty) return;
      rows.add(InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(ic, size: 16, color: kSubtext),
              const SizedBox(width: 10),
              Expanded(
                child: Text(v,
                    style: const TextStyle(fontSize: 13, color: kText)),
              ),
              if (onTap != null)
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: v)),
                  child: const Icon(Icons.copy_rounded, size: 14, color: kSubtext),
                ),
            ],
          ),
        ),
      ));
    }

    add(Icons.person_outline, institution.contactName.isEmpty ? null : institution.contactName);
    add(Icons.phone_outlined, institution.phone,
        onTap: institution.phone == null ? null : () => _call(institution.phone!));
    add(Icons.email_outlined, institution.email,
        onTap: institution.email == null ? null : () => _email(institution.email!));
    add(Icons.location_on_outlined, institution.address);
    add(Icons.markunread_mailbox_outlined,
        institution.postalCode == null ? null : 'P.O. Box ${institution.postalCode}');
    add(Icons.qr_code_2_outlined, institution.shortId);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openMaps,
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text('Get Directions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (institution.phone != null && institution.phone!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call(institution.phone!),
                icon: const Icon(Icons.phone_rounded, size: 18, color: kSuccess),
                label: const Text('Call', style: TextStyle(color: kSuccess)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: kSuccess.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (context) => [
              if (!institution.isSuspended)
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Suspend'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'unsuspend',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Unsuspend'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Remove from App'),
                  ],
                ),
              ),
            ],
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              label: const Text('More'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                side: const BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'suspend':
        _showSuspendDialog(context);
        break;
      case 'unsuspend':
        _unsuspendInstitution(context);
        break;
      case 'delete':
        _deleteInstitution(context);
        break;
    }
  }

  void _showSuspendDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Institution'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _suspendInstitution(context, reasonCtrl.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Suspend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendInstitution(BuildContext context, String reason) async {
    try {
      await dio.post(
        'institutions/${institution.id}/suspend',
        data: {'reason': reason.isNotEmpty ? reason : null},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institution suspended')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unsuspendInstitution(BuildContext context) async {
    try {
      await dio.post('institutions/${institution.id}/unsuspend');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institution unsuspended')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteInstitution(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Institution'),
        content: const Text('This institution will be removed from the app. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await dio.delete('institutions/${institution.id}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institution removed')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
