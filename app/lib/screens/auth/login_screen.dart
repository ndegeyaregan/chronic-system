import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';

const String _kProductsUrl =
    'https://ug.sanlamallianz.com/life-insurance/individuals';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  // Login logic state ─────────────────────────────────────────────────────────
  final _memberFormKey = GlobalKey<FormState>();
  final _memberNumberCtrl = TextEditingController();
  final _memberPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricLoading = false;
  List<BiometricType> _biometricTypes = [];
  int _modeIndex = 0; // 0 = member number, 1 = biometric

  // Animation controllers ─────────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _checkBiometrics();
    WidgetsBinding.instance.addPostFrameCallback((_) => _entryCtrl.forward());
  }

  @override
  void dispose() {
    _memberNumberCtrl.dispose();
    _memberPasswordCtrl.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
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

  void _setMode(int i) {
    setState(() => _modeIndex = i);
    if (i == 1) _checkBiometrics();
  }

  // Login logic — UNCHANGED ───────────────────────────────────────────────────
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

  Future<void> _openProducts() async {
    final uri = Uri.parse(_kProductsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the products page')),
        );
      }
    }
  }

  // Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            // ── Animated mesh-gradient header with curved bottom ────────────
            ClipPath(
              clipper: _HeaderCurveClipper(),
              child: SizedBox(
                height: size.height * 0.46,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _MeshGradientPainter(progress: _bgCtrl.value),
                  ),
                ),
              ),
            ),

            // ── Floating ambient blobs in header ────────────────────────────
            Positioned(
              top: -50, right: -40,
              child: _Blob(size: 220, alpha: 0.08),
            ),
            Positioned(
              top: 60, right: 80,
              child: _Blob(size: 60, alpha: 0.10),
            ),
            Positioned(
              top: 130, left: -30,
              child: _Blob(size: 100, alpha: 0.07),
            ),

            // ── Main scrollable content ─────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.00,
                      child: _buildHeroLogo(),
                    ),
                    const SizedBox(height: 22),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.10,
                      child: _buildWelcomeBlock(),
                    ),
                    const SizedBox(height: 18),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.22,
                      child: _buildLoginCard(authState),
                    ),
                    if (authState.error != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorBar(authState.error!),
                    ],
                    const SizedBox(height: 22),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.42,
                      child: _buildSectionDivider('EXPLORE MORE'),
                    ),
                    const SizedBox(height: 12),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _OtherProductsCard(onView: _openProducts),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _StaggeredEntry(
                      controller: _entryCtrl,
                      delay: 0.60,
                      child: _buildFooter(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero Logo (transparent PNG, embedded in gradient) ─────────────────────
  Widget _buildHeroLogo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Image.asset(
          'assets/images/login_logo.png',
          height: 44,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── Welcome text block ───────────────────────────────────────────────────
  Widget _buildWelcomeBlock() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Sign in to your member portal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Login card (floats over header) ──────────────────────────────────────
  Widget _buildLoginCard(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kPrimaryDark.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          children: [
            _SegmentedTabs(
              labels: const ['Member Number', 'Biometric'],
              icons: const [Icons.badge_outlined, Icons.fingerprint],
              selected: _modeIndex,
              onChanged: _setMode,
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _modeIndex == 0
                  ? _buildMemberPanel(authState)
                  : _buildBiometricPanel(authState),
            ),
          ],
        ),
      ),
    );
  }

  // ── Member Number panel ──────────────────────────────────────────────────
  Widget _buildMemberPanel(AuthState authState) {
    return Form(
      key: _memberFormKey,
      child: Column(
        key: const ValueKey('member'),
        children: [
          _PremiumField(
            controller: _memberNumberCtrl,
            label: 'Member Number',
            hint: 'e.g. 333307-00',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter member number' : null,
          ),
          const SizedBox(height: 12),
          _PremiumField(
            controller: _memberPasswordCtrl,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loginMemberNumber(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: kSubtext,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 18),
          _GradientButton(
            label: 'Sign In',
            isLoading: authState.isLoading,
            onPressed: _loginMemberNumber,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(routeForgotPassword),
            style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Forgot password?'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 13, color: kSubtext),
              ),
              GestureDetector(
                onTap: () => context.push(routeRegisterSearch),
                child: const Text(
                  'Create one',
                  style: TextStyle(
                    fontSize: 13,
                    color: kPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Biometric panel ──────────────────────────────────────────────────────
  Widget _buildBiometricPanel(AuthState authState) {
    final typeLabel = _biometricTypes.contains(BiometricType.face)
        ? 'Face ID'
        : _biometricTypes.contains(BiometricType.fingerprint)
            ? 'Fingerprint'
            : 'Biometrics';
    final iconData = _biometricTypes.contains(BiometricType.face)
        ? Icons.face_unlock_outlined
        : Icons.fingerprint;

    return Padding(
      key: const ValueKey('biometric'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        children: [
          if (!_biometricAvailable) ...[
            const SizedBox(height: 18),
            const Icon(Icons.fingerprint, size: 64, color: kBorder),
            const SizedBox(height: 12),
            const Text('Biometrics not available',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kText)),
            const SizedBox(height: 6),
            const Text(
              'Your device does not support fingerprint or Face ID,\n'
              'or no biometrics are enrolled.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kSubtext, height: 1.5),
            ),
            const SizedBox(height: 16),
            _OutlinedAction(
              label: 'Use Member Number',
              icon: Icons.badge_outlined,
              onPressed: () => _setMode(0),
            ),
          ] else if (!_biometricEnabled) ...[
            const SizedBox(height: 18),
            Icon(iconData, size: 64, color: kBorder),
            const SizedBox(height: 12),
            Text('$typeLabel not set up',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kText)),
            const SizedBox(height: 6),
            Text(
              'Sign in with your member number first, then enable\n'
              '$typeLabel for faster access.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: kSubtext, height: 1.5),
            ),
            const SizedBox(height: 16),
            _OutlinedAction(
              label: 'Use Member Number',
              icon: Icons.badge_outlined,
              onPressed: () => _setMode(0),
            ),
          ] else ...[
            const SizedBox(height: 8),
            _PulsingBiometricBadge(icon: iconData),
            const SizedBox(height: 14),
            Text('Sign in with $typeLabel',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            const SizedBox(height: 4),
            const Text('Tap below to authenticate',
                style: TextStyle(fontSize: 12.5, color: kSubtext)),
            const SizedBox(height: 18),
            _GradientButton(
              label: 'Use $typeLabel',
              isLoading: _biometricLoading || authState.isLoading,
              onPressed: _loginWithBiometrics,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await biometricService.disable();
                await _checkBiometrics();
              },
              style: TextButton.styleFrom(
                foregroundColor: kSubtext,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              child: const Text('Remove biometric login'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Error bar ────────────────────────────────────────────────────────────
  Widget _buildErrorBar(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kError.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kError.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: kError, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: kError, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section divider ──────────────────────────────────────────────────────
  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFD9E2F1), thickness: 1)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: kSubtext,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFD9E2F1), thickness: 1)),
        ],
      ),
    );
  }

  // ── Footer trust + version ───────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 13, color: kSubtext.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              'Secured with 256-bit encryption',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: kSubtext.withValues(alpha: 0.85),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '© Sanlam Allianz · v1.0.0',
          style: TextStyle(
            fontSize: 10.5,
            color: kSubtext.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Reusable widgets
// ════════════════════════════════════════════════════════════════════════════

/// Curved bottom for the header — soft S-curve, not a sharp arc.
class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path();
    p.lineTo(0, s.height - 50);
    p.quadraticBezierTo(s.width * 0.25, s.height - 10, s.width * 0.55, s.height - 30);
    p.quadraticBezierTo(s.width * 0.85, s.height - 55, s.width, s.height - 22);
    p.lineTo(s.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Multi-radial mesh gradient that slowly drifts.
class _MeshGradientPainter extends CustomPainter {
  final double progress;
  _MeshGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF001A52), Color(0xFF003DA5), Color(0xFF1A56C4)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    void drift(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final t = progress * 2 * math.pi;
    drift(
      Offset(size.width * 0.20 + math.sin(t) * 30,
          size.height * 0.30 + math.cos(t) * 20),
      size.width * 0.55,
      const Color(0xFF2A78FF).withValues(alpha: 0.55),
    );
    drift(
      Offset(size.width * 0.85 + math.cos(t * 0.7) * 24,
          size.height * 0.20 + math.sin(t * 0.7) * 18),
      size.width * 0.45,
      const Color(0xFF7B3DFF).withValues(alpha: 0.30),
    );
    drift(
      Offset(size.width * 0.50 + math.sin(t * 0.5) * 40,
          size.height * 0.85 + math.cos(t * 0.5) * 26),
      size.width * 0.55,
      const Color(0xFF00C2FF).withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter old) =>
      old.progress != progress;
}

/// Soft translucent floating circle.
class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      );
}

/// Slide-up + fade-in entrance helper, time-staggered along a parent controller.
class _StaggeredEntry extends StatelessWidget {
  final AnimationController controller;
  final double delay; // 0..1
  final Widget child;
  const _StaggeredEntry({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, math.min(1.0, delay + 0.55), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) {
        final v = curve.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Pill segmented control inside a soft grey track.
class _SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegmentedTabs({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final segW = (c.maxWidth - 8) / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selected * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final isOn = i == selected;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icons[i],
                                size: 16,
                                color: isOn ? kPrimary : kSubtext),
                            const SizedBox(width: 6),
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isOn ? FontWeight.w700 : FontWeight.w500,
                                color: isOn ? kPrimary : kSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Soft filled input with focus glow.
class _PremiumField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.textInputAction,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
  });

  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kText,
              letterSpacing: 0.1,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : const Color(0xFFF6F8FC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _focused ? kPrimary : const Color(0xFFE2E8F0),
              width: _focused ? 1.4 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            textInputAction: widget.textInputAction,
            keyboardType: widget.keyboardType,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: kText),
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: kTextLight,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(widget.icon,
                    size: 20,
                    color: _focused ? kPrimary : kSubtext),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: widget.suffix,
              contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium gradient button with soft glow + loading state.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimaryDark, kPrimary, kPrimaryLight],
          ),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.40),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _OutlinedAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Concentric pulsing rings around the biometric icon.
class _PulsingBiometricBadge extends StatefulWidget {
  final IconData icon;
  const _PulsingBiometricBadge({required this.icon});

  @override
  State<_PulsingBiometricBadge> createState() => _PulsingBiometricBadgeState();
}

class _PulsingBiometricBadgeState extends State<_PulsingBiometricBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 2; i++)
                _ring(((_ctrl.value + i * 0.5) % 1.0)),
              Container(
                width: 78, height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kPrimaryDark, kPrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 38),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double t) {
    return Container(
      width: 78 + t * 32,
      height: 78 + t * 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kPrimary.withValues(alpha: (1 - t) * 0.40),
          width: 2,
        ),
      ),
    );
  }
}

// ── Premium "Sanlam Other Products" card ────────────────────────────────────
class _OtherProductsCard extends StatefulWidget {
  final VoidCallback onView;
  const _OtherProductsCard({required this.onView});

  @override
  State<_OtherProductsCard> createState() => _OtherProductsCardState();
}

class _OtherProductsCardState extends State<_OtherProductsCard>
    with TickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shine.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onView,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B2447),
                Color(0xFF0A4D8C),
                Color(0xFF1976D2),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A4D8C).withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -30, top: -30,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  left: -20, bottom: -40,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _shine,
                  builder: (_, __) => Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment(-1.5 + _shine.value * 3.0, 0),
                          child: Transform.rotate(
                            angle: -0.6,
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.18),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _float,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _float.value * 4 - 2),
                        child: child,
                      ),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.10),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sanlam Other Products',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Life cover, education plans &\nfamily protection — explore more',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              color: Color(0xFF0A4D8C),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFF0A4D8C), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
