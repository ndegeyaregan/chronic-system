import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class CreatePasswordScreen extends ConsumerStatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  ConsumerState<CreatePasswordScreen> createState() =>
      _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  double _strength = 0;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _checkStrength(String val) {
    double s = 0;
    if (val.length >= 8) s += 0.25;
    if (val.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (val.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.25;
    setState(() => _strength = s);
  }

  String get _strengthLabel {
    if (_strength <= 0.25) return 'Weak';
    if (_strength <= 0.5) return 'Fair';
    if (_strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    if (_strength <= 0.25) return kError;
    if (_strength <= 0.5) return kWarning;
    if (_strength <= 0.75) return const Color(0xFF3B82F6);
    return kSuccess;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authProvider.notifier)
        .createPassword(_passwordCtrl.text, _confirmCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final member = authState.member;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_outlined,
                    color: kPrimary, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${member?.firstName ?? 'Member'}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please create a password to secure your account.',
                style: TextStyle(fontSize: 14, color: kSubtext),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppInput(
                        label: 'New Password',
                        hint: 'At least 8 characters',
                        controller: _passwordCtrl,
                        obscureText: true,
                        showPasswordToggle: true,
                        prefixIcon:
                            const Icon(Icons.lock_outline, color: kSubtext),
                        onChanged: _checkStrength,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter a password';
                          }
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_passwordCtrl.text.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _strength,
                                  backgroundColor: kBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _strengthColor),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _strengthLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _strengthColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use uppercase, numbers & special characters for a stronger password.',
                          style: TextStyle(fontSize: 11, color: kSubtext),
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppInput(
                        label: 'Confirm Password',
                        hint: 'Repeat your password',
                        controller: _confirmCtrl,
                        obscureText: true,
                        showPasswordToggle: true,
                        prefixIcon:
                            const Icon(Icons.lock_outline, color: kSubtext),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (authState.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          authState.error!,
                          style:
                              const TextStyle(color: kError, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Create Password',
                        onPressed: _submit,
                        isLoading: authState.isLoading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '🔒  Your password is encrypted and never stored in plain text.',
                  style: TextStyle(fontSize: 12, color: kSubtext),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
