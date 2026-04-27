import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _memberFormKey = GlobalKey<FormState>();

  final _memberNumberCtrl = TextEditingController();
  final _memberPasswordCtrl = TextEditingController();

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricLoading = false;
  List<BiometricType> _biometricTypes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _checkBiometrics();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _memberNumberCtrl.dispose();
    _memberPasswordCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await biometricService.isAvailable();
    final enabled = await biometricService.isEnabled();
    final types = await biometricService.availableTypes();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _biometricTypes = types;
      });
    }
  }

  void _loginMemberNumber() {
    if (!_memberFormKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).loginWithMemberNumber(
          _memberNumberCtrl.text.trim(),
          _memberPasswordCtrl.text,
        );
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _biometricLoading = true);
    await ref.read(authProvider.notifier).loginWithBiometrics();
    if (mounted) setState(() => _biometricLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    ref.listen<AuthState>(authProvider, (prev, next) {
      // Navigation is handled by GoRouter redirect
    });

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: screenHeight * 0.42,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryDark, kPrimary, kPrimaryLight],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 40, right: 60,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  _buildHeroLogo(),
                  const SizedBox(height: 36),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(kRadiusXl),
                      boxShadow: kShadowMd,
                    ),
                    child: Column(
                      children: [
                        _buildTabBar(),
                        SizedBox(
                          height: 340,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMemberNumberTab(authState),
                              _buildBiometricTab(authState),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kError.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        border: Border.all(color: kError.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: kError, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(authState.error!,
                                style: const TextStyle(color: kError, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => context.push(routeForgotPassword),
                    child: const Text('Forgot password?',
                        style: TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroLogo() {
    return Column(
      children: [
        const Text('Chronic Care',
            style: TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('Your health, simplified',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder, width: 1))),
      child: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(vertical: 16),
        indicator: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kPrimary, width: 2.5))),
        labelColor: kPrimary,
        unselectedLabelColor: kSubtext,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Member Number'),
          Tab(text: 'Biometric Login'),
        ],
      ),
    );
  }

  Widget _buildMemberNumberTab(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Form(
        key: _memberFormKey,
        child: Column(
          children: [
            AppInput(
              label: 'Member Number',
              hint: 'e.g. 333307-00',
              controller: _memberNumberCtrl,
              prefixIcon: const Icon(Icons.badge_outlined),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter member number' : null,
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Password',
              hint: 'Enter your password',
              controller: _memberPasswordCtrl,
              obscureText: true,
              showPasswordToggle: true,
              prefixIcon: const Icon(Icons.lock_outline),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loginMemberNumber(),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter password' : null,
            ),
            const Spacer(),
            AppButton(
              label: 'Sign In',
              onPressed: _loginMemberNumber,
              isLoading: authState.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricTab(AuthState authState) {
    final typeLabel = _biometricTypes.contains(BiometricType.face)
        ? 'Face ID'
        : _biometricTypes.contains(BiometricType.fingerprint)
            ? 'Fingerprint'
            : 'Biometrics';

    final iconData = _biometricTypes.contains(BiometricType.face)
        ? Icons.face_unlock_outlined
        : Icons.fingerprint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_biometricAvailable) ...[
            const Icon(Icons.fingerprint, size: 72, color: kBorder),
            const SizedBox(height: 16),
            const Text('Biometrics not available',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: kText),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Your device does not support fingerprint or Face ID, '
              'or no biometrics are enrolled.\n\n'
              'Please use the Member Number tab to sign in.',
              style: TextStyle(fontSize: 13, color: kSubtext, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ] else if (!_biometricEnabled) ...[
            Icon(iconData, size: 72, color: kBorder),
            const SizedBox(height: 16),
            Text('$typeLabel not set up',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: kText),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Sign in with your member number first, then choose to enable '
              '$typeLabel login for faster access.',
              style: const TextStyle(fontSize: 13, color: kSubtext, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Sign in with Member Number'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusMd)),
              ),
            ),
          ] else ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryDark, kPrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(iconData, color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 20),
            Text('Sign in with $typeLabel',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
            const SizedBox(height: 8),
            const Text('Tap the button below to authenticate',
                style: TextStyle(fontSize: 13, color: kSubtext)),
            const SizedBox(height: 32),
            AppButton(
              label: 'Use $typeLabel',
              onPressed: _loginWithBiometrics,
              isLoading: _biometricLoading || authState.isLoading,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await biometricService.disable();
                await _checkBiometrics();
              },
              child: const Text('Remove biometric login',
                  style: TextStyle(color: kSubtext, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
