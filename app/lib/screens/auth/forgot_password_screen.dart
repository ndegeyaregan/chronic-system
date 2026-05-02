import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

/// Two-step forgot-password flow:
///   1. Member enters their member number → backend tells us which channels
///      (email / SMS) Sanlam has on file, with masked previews.
///   2. Member taps the channel they want → backend asks Sanlam to send the
///      OTP via that channel only, then we navigate to the verify screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { input, choose }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNumberCtrl = TextEditingController();

  _Step _step = _Step.input;
  bool _loading = false;
  String? _error;

  String _memberNumber = '';
  bool _hasEmail = false;
  bool _hasPhone = false;
  String _maskedEmail = '';
  String _maskedPhone = '';

  @override
  void dispose() {
    _memberNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _memberNumber = _memberNumberCtrl.text.trim();
      final m = await authService.lookupForgotPasswordContact(_memberNumber);
      _hasEmail = m['hasEmail'] == true;
      _hasPhone = m['hasPhone'] == true;
      _maskedEmail = (m['maskedEmail'] ?? '').toString();
      _maskedPhone = (m['maskedPhone'] ?? '').toString();
      if (!_hasEmail && !_hasPhone) {
        setState(() => _error =
            'No email or phone is registered on your Sanlam member profile. '
            'Please contact Sanlam to add one.');
        return;
      }
      setState(() => _step = _Step.choose);
    } on DioException catch (e) {
      setState(() => _error =
          (e.response?.data is Map ? e.response?.data['message'] : null) ??
              'Could not look up your contact details. Try again.');
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(int sendMode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await authService.requestPasswordResetByMemberNo(
        _memberNumber,
        sendMode: sendMode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push(routeVerifyOtp, extra: _memberNumber);
    } on DioException catch (e) {
      setState(() => _error =
          (e.response?.data is Map ? e.response?.data['message'] : null) ??
              'Could not send the OTP. Try the other option or try again later.');
    } catch (e) {
      final s = e.toString();
      setState(() => _error = s.contains('SanlamApiException')
          ? s.split(':').last.trim()
          : 'An unexpected error occurred.');
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kText, size: 20),
          onPressed: () {
            if (_step == _Step.choose) {
              setState(() {
                _step = _Step.input;
                _error = null;
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == _Step.input ? _buildInput() : _buildChoose(),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_outlined,
              color: kPrimary, size: 36),
        ),
        const SizedBox(height: 24),
        const Text(
          'Forgot Password?',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: kText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your member number and we will check which contact methods '
          'are on file for you.',
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
                  prefixIcon:
                      const Icon(Icons.badge_outlined, color: kSubtext),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _lookup(),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your member number'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: _error!),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Continue',
                  onPressed: _lookup,
                  isLoading: _loading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoose() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Where should we send the OTP?',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: kText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Pick the contact method you would like Sanlam to use for member '
          '$_memberNumber.',
          style: const TextStyle(fontSize: 14, color: kSubtext, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_hasEmail)
          _ChannelCard(
            icon: Icons.email_outlined,
            title: 'Email me the OTP',
            subtitle: _maskedEmail.isEmpty
                ? 'Sent to your registered email'
                : 'Sent to $_maskedEmail',
            onTap: _loading ? null : () => _send(1),
          ),
        if (_hasEmail && _hasPhone) const SizedBox(height: 12),
        if (_hasPhone)
          _ChannelCard(
            icon: Icons.sms_outlined,
            title: 'Text me the OTP',
            subtitle: _maskedPhone.isEmpty
                ? 'Sent to your registered mobile'
                : 'Sent to $_maskedPhone',
            onTap: _loading ? null : () => _send(2),
          ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        if (_loading) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ChannelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusLg),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kText)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 13, color: kSubtext)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kSubtext),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(message,
                style: const TextStyle(color: kError, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
