import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_button.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String memberNumber;
  const VerifyOtpScreen({super.key, required this.memberNumber});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 digits filled
    if (_otp.length == 6) _submit();
    setState(() {});
  }

  Future<void> _submit() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final resetToken = await authService.verifyOtp(widget.memberNumber, _otp);
      if (!mounted) return;
      context.push(routeResetPassword, extra: {
        'memberNumber': widget.memberNumber,
        'resetToken': resetToken,
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message'] ?? 'Verification failed. Try again.';
        for (final c in _ctrls) c.clear();
      });
      _nodes[0].requestFocus();
    } catch (e) {
      setState(() {
        _error = e.toString().contains('SanlamApiException')
            ? e.toString().split(':').last.trim()
            : 'An unexpected error occurred.';
      });
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
                child: const Icon(Icons.sms_outlined, color: kPrimary, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter OTP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A 6-digit code was sent to the phone number or email linked to member ${widget.memberNumber}. The code expires in 10 minutes.',
                style: const TextStyle(fontSize: 14, color: kSubtext, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              // OTP digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _buildDigitBox(i)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              AppButton(
                label: 'Verify OTP',
                onPressed: _submit,
                isLoading: _loading,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Didn\'t receive it? Go back and try again',
                  style: TextStyle(color: kSubtext, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    final filled = _ctrls[index].text.isNotEmpty;
    return Container(
      width: 48, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: filled ? kPrimary : kBorder,
          width: filled ? 2 : 1,
        ),
        boxShadow: kShadowSm,
      ),
      child: TextFormField(
        controller: _ctrls[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: kText),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => _onDigitChanged(index, v),
      ),
    );
  }
}
