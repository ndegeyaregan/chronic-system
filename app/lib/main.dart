import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.init();

  final prefs = await SharedPreferences.getInstance();

  // For returning users with a saved session, restore their per-user onboarding
  // state so they are never forced back to the onboarding screen on cold start.
  bool onboardingComplete = false;
  final savedToken = await authService.getToken();
  if (savedToken != null && savedToken.isNotEmpty) {
    final member = authService.decodeTokenMember(savedToken);
    if (member != null && member.id.isNotEmpty) {
      onboardingComplete = prefs.getBool('onboarding_${member.id}')
          ?? prefs.getBool('onboarding_complete')
          ?? false;
    }
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (_) {
    // Firebase may not be configured in all environments.
    // The app will run without push notifications.
  }

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWith((ref) => onboardingComplete),
      ],
      child: const SanlamChronicApp(),
    ),
  );
}

class SanlamChronicApp extends ConsumerStatefulWidget {
  const SanlamChronicApp({super.key});

  @override
  ConsumerState<SanlamChronicApp> createState() => _SanlamChronicAppState();
}

class _SanlamChronicAppState extends ConsumerState<SanlamChronicApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      auth.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      auth.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Sanlam Chronic Care',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
