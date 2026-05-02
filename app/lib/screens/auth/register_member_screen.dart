import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../services/sanlam_api_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';
import 'terms_screen.dart';

/// Step 2 of registration: choose a password & accept T&Cs, then call
/// `RegMember` to create the account on the Sanlam server.
class RegisterMemberScreen extends StatefulWidget {
  final String memberNumber;
  final String memberName;
  const RegisterMemberScreen({
    super.key,
    required this.memberNumber,
    required this.memberName,
  });

  @override
  State<RegisterMemberScreen> createState() => _RegisterMemberScreenState();
}

class _RegisterMemberScreenState extends State<RegisterMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _accepted = false;
  bool _loading = false;
  String? _error;
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
    if (_strength <= 0.75) return kInfo;
    return kSuccess;
  }

  Future<void> _openTerms() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TermsScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {
        _accepted = true;
        if (_error == 'You must accept the Terms & Conditions to continue.') {
          _error = null;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'You must accept the Terms & Conditions to continue.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await authService.registerMember(
        memberNumber: widget.memberNumber,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      _showSuccess();
    } on SanlamApiException catch (e) {
      setState(() => _error = e.description);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['description']?.toString() ??
          'Registration failed. Try again.');
    } catch (_) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: kSuccess, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Account Created!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
            const SizedBox(height: 8),
            const Text(
              'Your account has been created successfully. Please log in with your member number and new password.',
              style: TextStyle(fontSize: 14, color: kSubtext, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(routeLogin);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Log In Now',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.memberName.isEmpty ? 'there' : widget.memberName;
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
              const SizedBox(height: 8),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_outlined, color: kSuccess, size: 36),
              ),
              const SizedBox(height: 16),
              Text('Hi $greetingName 👋',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: kText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Member ${widget.memberNumber}',
                  style: const TextStyle(fontSize: 13, color: kSubtext),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Set a password for your app account.',
                style: TextStyle(fontSize: 14, color: kSubtext),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                        label: 'Password',
                        hint: 'At least 8 characters',
                        controller: _passwordCtrl,
                        obscureText: true,
                        showPasswordToggle: true,
                        prefixIcon: const Icon(Icons.lock_outline, color: kSubtext),
                        onChanged: _checkStrength,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a password';
                          if (v.length < 8) return 'Password must be at least 8 characters';
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
                                  valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(_strengthLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _strengthColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppInput(
                        label: 'Confirm Password',
                        hint: 'Repeat your password',
                        controller: _confirmCtrl,
                        obscureText: true,
                        showPasswordToggle: true,
                        prefixIcon: const Icon(Icons.lock_outline, color: kSubtext),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Terms & Conditions gate. Either a primary "Read"
                      // button (when not yet accepted) or a green "accepted"
                      // pill with a small "View again" link.
                      if (!_accepted)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openTerms,
                            icon: const Icon(Icons.description_outlined,
                                color: kPrimary, size: 18),
                            label: const Text(
                              'Read Terms & Conditions',
                              style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadiusMd),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: kSuccess.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(kRadiusMd),
                            border: Border.all(
                                color: kSuccess.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: kSuccess, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'You agreed to the Terms & Conditions',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: kText,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              GestureDetector(
                                onTap: _openTerms,
                                child: const Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kPrimary,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
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
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Create Account',
                        onPressed: _accepted ? _submit : null,
                        isLoading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

