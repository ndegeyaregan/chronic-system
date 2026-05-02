import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/step_tracking_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/cms_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.init();
  await CMSService.init();
  await OfflineSyncService.init();

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
    // Listen for FCM token refreshes and re-register with backend
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await dio.put('/members/me', data: {'fcm_token': newToken});
      } catch (_) {}
    });
  } catch (_) {
    // Firebase may not be configured in all environments.
    // The app will still work with local notifications.
    await NotificationService.initialize();
  }

  // Load the cached Sanlam profile photo so the avatar shows immediately
  // on the home screen (before profile screen is opened).
  await authService.loadCachedSanlamPhoto();

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWith((ref) => onboardingComplete),
      ],
      child: const SanlamMemberApp(),
    ),
  );
}

class SanlamMemberApp extends ConsumerStatefulWidget {
  const SanlamMemberApp({super.key});

  @override
  ConsumerState<SanlamMemberApp> createState() => _SanlamMemberAppState();
}

class _SanlamMemberAppState extends ConsumerState<SanlamMemberApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Eagerly initialize the step tracking provider so it starts counting
    // steps as soon as the app launches (not only when a screen reads it).
    ref.read(stepTrackingProvider);
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
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'SanCare+',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
