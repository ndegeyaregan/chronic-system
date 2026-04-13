import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNumberCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _memberNumberCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  bool get _isEmail {
    final v = _contactCtrl.text.trim();
    return v.contains('@');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final contact = _contactCtrl.text.trim();
      await authService.requestPasswordReset(
        _memberNumberCtrl.text.trim(),
        phone: _isEmail ? null : contact,
        email: _isEmail ? contact : null,
      );
      if (!mounted) return;
      context.push(routeVerifyOtp, extra: _memberNumberCtrl.text.trim());
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Request failed. Try again.');
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
                child: const Icon(Icons.lock_reset_outlined, color: kPrimary, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your member number and the phone number or email address on your account. We will send you a one-time PIN.',
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
                        controller: _memberNumberCtrl,
                        prefixIcon: const Icon(Icons.badge_outlined, color: kSubtext),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter your member number' : null,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: 'Phone Number or Email',
                        hint: 'e.g. 0821234567 or name@email.com',
                        controller: _contactCtrl,
                        prefixIcon: const Icon(Icons.contact_phone_outlined, color: kSubtext),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your phone number or email address';
                          }
                          return null;
                        },
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
                        label: 'Send OTP',
                        onPressed: _submit,
                        isLoading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'The phone number or email must match what is registered in our system.',
                style: TextStyle(fontSize: 12, color: kSubtext),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
