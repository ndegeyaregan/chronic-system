import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: kSuccess,
        ),
      );
      context.go(routeProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_outlined,
                    color: kPrimary, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Your Password',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: kText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your current password and choose a new one.',
                style: TextStyle(fontSize: 13, color: kSubtext),
              ),
              const SizedBox(height: 28),
              AppInput(
                label: 'Current Password',
                hint: 'Enter your current password',
                controller: _currentCtrl,
                obscureText: true,
                showPasswordToggle: true,
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kSubtext),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter current password' : null,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'New Password',
                hint: 'At least 8 characters',
                controller: _newCtrl,
                obscureText: true,
                showPasswordToggle: true,
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kSubtext),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter new password';
                  if (v.length < 8) return 'Minimum 8 characters';
                  if (v == _currentCtrl.text) {
                    return 'New password must differ from current';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Confirm New Password',
                hint: 'Repeat your new password',
                controller: _confirmCtrl,
                obscureText: true,
                showPasswordToggle: true,
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kSubtext),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: kError, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              AppButton(
                label: 'Change Password',
                onPressed: _submit,
                isLoading: authState.isLoading,
                leadingIcon: Icons.check_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
