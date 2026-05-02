import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../services/sanlam_api_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

/// Step 1 of registration: confirm the member exists in Sanlam's records.
/// Calls `SearchForReg` which requires MemberNo + LastName + DOB.
class RegisterSearchScreen extends StatefulWidget {
  const RegisterSearchScreen({super.key});

  @override
  State<RegisterSearchScreen> createState() => _RegisterSearchScreenState();
}

class _RegisterSearchScreenState extends State<RegisterSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _dob;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _memberCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _fmtDob(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      setState(() => _error = 'Please select your date of birth');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await authService.searchForRegistration(
        memberNumber: _memberCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dob: _fmtDob(_dob!),
      );
      if (!mounted) return;
      final memberName = (result['memberName'] ??
              result['MemberName'] ??
              '${result['firstName'] ?? ''} ${result['lastName'] ?? ''}')
          .toString()
          .trim();
      context.push(routeRegisterMember, extra: <String, dynamic>{
        'memberNumber': _memberCtrl.text.trim(),
        'memberName': memberName,
      });
    } on SanlamApiException catch (e) {
      setState(() => _error = e.description);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['description']?.toString() ??
          'Search failed. Try again.');
    } catch (_) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_outlined, color: kPrimary, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'First, let\'s confirm your Sanlam membership. Enter the details exactly as they appear on your medical card.',
                style: TextStyle(fontSize: 14, color: kSubtext, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: kShadowMd,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppInput(
                        label: 'Member Number',
                        hint: 'e.g. 333307-00',
                        controller: _memberCtrl,
                        prefixIcon: const Icon(Icons.badge_outlined, color: kSubtext),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter your member number' : null,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: 'Last Name',
                        hint: 'Surname',
                        controller: _lastNameCtrl,
                        prefixIcon: const Icon(Icons.person_outline, color: kSubtext),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter your last name' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: const Icon(Icons.calendar_today_outlined,
                                color: kSubtext, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(kRadiusMd),
                            ),
                          ),
                          child: Text(
                            _dob == null ? 'Tap to choose' : _fmtDob(_dob!),
                            style: TextStyle(
                              color: _dob == null ? kSubtext : kText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: kError.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(kRadiusMd),
                            border: Border.all(color: kError.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: kError, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(color: kError, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Continue',
                        onPressed: _submit,
                        isLoading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(routeLogin),
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
