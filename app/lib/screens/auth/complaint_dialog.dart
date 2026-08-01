import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../core/app_colors.dart';

class _CategoryOption {
  final String value;
  final String label;
  final IconData icon;
  const _CategoryOption(this.value, this.label, this.icon);
}

const List<_CategoryOption> _categories = [
  _CategoryOption('system_error', 'System Error', Icons.bug_report_outlined),
  _CategoryOption('preauth_delay', 'Pre-authorisation Delay', Icons.hourglass_bottom_outlined),
  _CategoryOption('failing_to_register', 'Failing to Register', Icons.app_registration),
  _CategoryOption('prolonged_turnaround_time', 'Prolonged Turnaround Time', Icons.timer_outlined),
];

Future<void> showComplaintDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: _ComplaintForm(),
    ),
  );
}

class _ComplaintForm extends StatefulWidget {
  const _ComplaintForm();

  @override
  State<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<_ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  String? _category;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_category == null) {
      setState(() => _error = 'Please select a category');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final hasContact = _emailCtrl.text.trim().isNotEmpty ||
        _phoneCtrl.text.trim().isNotEmpty ||
        _memberCtrl.text.trim().isNotEmpty;
    if (!hasContact) {
      setState(() => _error =
          'Please provide at least one contact detail (email, phone, or member number)');
      return;
    }

    setState(() => _submitting = true);
    try {
      await dio.post('/complaints', data: {
        'category': _category,
        'description': _descCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_memberCtrl.text.trim().isNotEmpty)
          'member_number': _memberCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Complaint submitted. Our team will get back to you shortly.'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      final msg = (e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null)
          ? (e.response!.data as Map)['message'].toString()
          : 'Could not submit. Please check your connection and try again.';
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 20, color: context.c.subtext),
        filled: true,
        fillColor: context.c.surfaceAlt,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 480,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            decoration: const BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Register a Complaint',
                    style: TextStyle(
                      color: context.c.cardBg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tell us what went wrong and we\'ll get back to you.',
                      style: TextStyle(fontSize: 13, color: context.c.subtext),
                    ),
                    const SizedBox(height: 16),
                    Text('Category',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.c.text)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: _dec('Select an issue',
                          icon: Icons.category_outlined),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c.value,
                                child: Row(
                                  children: [
                                    Icon(c.icon, size: 18, color: kPrimary),
                                    const SizedBox(width: 10),
                                    Flexible(
                                        child: Text(c.label,
                                            overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 14),
                    Text('Describe the issue',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.c.text)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      maxLength: 5000,
                      enabled: !_submitting,
                      decoration:
                          _dec('Describe what happened…').copyWith(
                        alignLabelWithHint: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please describe the issue';
                        }
                        if (v.trim().length < 10) {
                          return 'Please add a bit more detail (10+ chars)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text('Contact details',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.c.text)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          _dec('Email', icon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(v.trim());
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      decoration:
                          _dec('Phone', icon: Icons.phone_outlined),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _memberCtrl,
                      enabled: !_submitting,
                      decoration: _dec('Member Number',
                          icon: Icons.badge_outlined),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: kError.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(kRadiusMd),
                          border: Border.all(
                              color: kError.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: kError, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: kError, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: context.c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(color: context.c.text)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : Text('Submit',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
