import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../providers/member_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../services/api_service.dart';

const _conditions = [
  'Hypertension',
  'Diabetes',
  'Heart Disease',
  'COPD',
  'Kidney Disease',
  'Asthma',
  'HIV/AIDS',
  'Arthritis',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Condition page state
  Set<String> _selectedConditions = {};

  // Buddy page state
  final _buddyNameCtrl = TextEditingController();
  final _buddyPhoneCtrl = TextEditingController();
  final _buddyRelCtrl = TextEditingController();
  bool _savingConditions = false;
  bool _savingBuddy = false;

  @override
  void initState() {
    super.initState();
    // Pre-select any conditions from existing member profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final member = ref.read(memberProvider).member ??
          ref.read(authProvider).member;
      if (member != null && member.conditions.isNotEmpty) {
        setState(() {
          _selectedConditions = Set.from(member.conditions);
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _buddyNameCtrl.dispose();
    _buddyPhoneCtrl.dispose();
    _buddyRelCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final member = ref.read(authProvider).member;
    final prefs = await SharedPreferences.getInstance();
    // Save per-user key so each member's onboarding state is independent
    if (member != null && member.id.isNotEmpty) {
      await prefs.setBool('onboarding_${member.id}', true);
    }
    await prefs.setBool('onboarding_complete', true); // global fallback
    ref.read(onboardingCompleteProvider.notifier).state = true;
    if (mounted) context.go(routeDashboard);
  }

  Future<void> _saveConditionsAndNext() async {
    setState(() => _savingConditions = true);
    try {
      await dio.put(
        '/members/me/conditions',
        data: {'conditions': _selectedConditions.toList()},
      );
      // Refresh member profile
      await ref.read(memberProvider.notifier).fetchProfile();
    } on DioException catch (_) {
      // Conditions save is best-effort; proceed regardless
    } finally {
      if (mounted) setState(() => _savingConditions = false);
    }
    _nextPage();
  }

  Future<void> _saveBuddyAndNext() async {
    final name = _buddyNameCtrl.text.trim();
    final phone = _buddyPhoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _nextPage();
      return;
    }
    setState(() => _savingBuddy = true);
    try {
      await dio.post('/buddies', data: {
        'name': name,
        'phone': phone,
        'relationship': _buddyRelCtrl.text.trim().isNotEmpty
            ? _buddyRelCtrl.text.trim()
            : null,
      });
    } on DioException catch (_) {
      // Buddy save is best-effort; proceed regardless
    } finally {
      if (mounted) setState(() => _savingBuddy = false);
    }
    _nextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _WelcomePage(onNext: _nextPage),
              _ConditionsPage(
                selected: _selectedConditions,
                onToggle: (c) => setState(() {
                  if (_selectedConditions.contains(c)) {
                    _selectedConditions.remove(c);
                  } else {
                    _selectedConditions.add(c);
                  }
                }),
                onNext: _saveConditionsAndNext,
                saving: _savingConditions,
              ),
              _BuddyPage(
                nameCtrl: _buddyNameCtrl,
                phoneCtrl: _buddyPhoneCtrl,
                relCtrl: _buddyRelCtrl,
                onNext: _saveBuddyAndNext,
                onSkip: _nextPage,
                saving: _savingBuddy,
              ),
              _SummaryPage(onFinish: _completeOnboarding),
            ],
          ),
          // Progress dots
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Row(
                    children: List.generate(4, (i) => _Dot(active: i == _currentPage)),
                  ),
                  const Spacer(),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: _currentPage == 0
                              ? Colors.white
                              : kSubtext,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 6),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white38,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Page 1: Welcome ────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002880), Color(0xFF1A56C4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Logo placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Welcome to\nSanCare',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your personal health companion for managing chronic conditions with confidence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              _OnboardingButton(
                label: 'Get Started',
                onTap: onNext,
                white: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 2: Conditions ────────────────────────────────────────────────────

class _ConditionsPage extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  final VoidCallback onNext;
  final bool saving;

  const _ConditionsPage({
    required this.selected,
    required this.onToggle,
    required this.onNext,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002880), Color(0xFF1A56C4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the conditions you manage. This helps us personalise your care.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: _conditions.length,
                  itemBuilder: (_, i) {
                    final c = _conditions[i];
                    final isSelected = selected.contains(c);
                    return GestureDetector(
                      onTap: () => onToggle(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? kPrimary : Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: isSelected ? kPrimary : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _OnboardingButton(
                label: saving ? null : 'Next',
                onTap: saving ? null : onNext,
                white: true,
                loading: saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 3: Chronic Care Buddy ────────────────────────────────────────────

class _BuddyPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relCtrl;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool saving;

  const _BuddyPage({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.relCtrl,
    required this.onNext,
    required this.onSkip,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002880), Color(0xFF1A56C4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Care Buddy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add someone we can reach if you are unreachable — a family member, friend, or caregiver.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
              _WhiteField(
                controller: nameCtrl,
                label: 'Full name',
                hint: 'e.g. Jane Doe',
              ),
              const SizedBox(height: 14),
              _WhiteField(
                controller: phoneCtrl,
                label: 'Phone number',
                hint: 'e.g. +256 7XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _WhiteField(
                controller: relCtrl,
                label: 'Relationship (optional)',
                hint: 'e.g. Spouse, Parent, Sibling',
              ),
              const Spacer(),
              _OnboardingButton(
                label: saving ? null : 'Save & Continue',
                onTap: saving ? null : onNext,
                white: true,
                loading: saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _WhiteField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: kText, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Page 4: Summary ───────────────────────────────────────────────────────

class _SummaryPage extends StatelessWidget {
  final VoidCallback onFinish;
  const _SummaryPage({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002880), Color(0xFF00C853)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: kAccent, size: 50),
              ),
              const SizedBox(height: 40),
              const Text(
                "You're all set!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your profile is ready. Start tracking your health, medications, and appointments from your personalised dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              _OnboardingButton(
                label: 'Go to Dashboard',
                onTap: onFinish,
                white: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared button ─────────────────────────────────────────────────────────

class _OnboardingButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;
  final bool white;
  final bool loading;

  const _OnboardingButton({
    required this.label,
    required this.onTap,
    this.white = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: white ? Colors.white : kPrimary,
          disabledBackgroundColor: white
              ? Colors.white.withValues(alpha: 0.6)
              : kPrimary.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: white ? kPrimary : Colors.white,
                ),
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  color: white ? kPrimary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
