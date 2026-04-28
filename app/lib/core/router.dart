import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/member_type_provider.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/create_password_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/chronic_dashboard_screen.dart';
import '../screens/home/member_dashboard_screen.dart';
import '../widgets/common/chronic_only.dart';
import '../screens/medications/medications_screen.dart';
import '../screens/medications/add_medication_screen.dart';
import '../screens/medications/medication_detail_screen.dart';
import '../screens/vitals/vitals_screen.dart';
import '../screens/vitals/log_vitals_screen.dart';
import '../screens/vitals/vitals_history_screen.dart';
import '../screens/appointments/appointments_screen.dart';
import '../screens/appointments/book_appointment_screen.dart';
import '../screens/appointments/appointment_detail_screen.dart';
import '../screens/lifestyle/lifestyle_screen.dart';
import '../screens/lifestyle/log_meal_screen.dart';
import '../screens/lifestyle/log_fitness_screen.dart';
import '../screens/lifestyle/partner_locator_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/my_provider_screen.dart';
import '../screens/treatment/treatment_screen.dart';
import '../screens/lab_results/lab_results_screen.dart';
import '../screens/authorizations/request_authorization_screen.dart';
import '../screens/authorizations/authorizations_screen.dart';
import '../screens/health_facilities/facility_finder_screen.dart';
import '../screens/education/condition_education_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/emergency/emergency_sos_screen.dart';
import '../screens/benefits/benefits_screen.dart';
import '../screens/claims/claims_screen.dart';
import '../screens/claims/claim_detail_screen.dart';
import '../screens/dependants/dependants_list_screen.dart';
import '../screens/dependants/dependant_detail_screen.dart';
import '../screens/membership_card/membership_card_screen.dart';
import '../screens/preauth/preauth_list_screen.dart';
import '../screens/preauth/preauth_detail_screen.dart';
import '../screens/network/network_providers_screen.dart';
import '../models/visit.dart';
import '../models/dependant.dart';
import '../models/preauth.dart';
import 'constants.dart';

class GoRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  GoRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<bool>(onboardingCompleteProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<bool>(isChronicMemberProvider, (_, __) {
      notifyListeners();
    });
  }

  AuthState get authState => _ref.read(authProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteProvider);
  bool get isChronicMember => _ref.read(isChronicMemberProvider);
}

final goRouterNotifierProvider =
    ChangeNotifierProvider((ref) => GoRouterNotifier(ref));

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(goRouterNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: routeSplash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.authState;
      final location = state.matchedLocation;

      if (auth.status == AuthStatus.loading) return null;

      if (auth.status == AuthStatus.needsPassword) {
        if (location != routeCreatePassword) return routeCreatePassword;
        return null;
      }

      if (auth.status == AuthStatus.unauthenticated) {
        if (location == routeLogin ||
            location == routeForgotPassword ||
            location == routeVerifyOtp ||
            location == routeResetPassword) return null;
        return routeLogin;
      }

      if (auth.status == AuthStatus.authenticated) {
        if (location == routeLogin ||
            location == routeSplash ||
            location == routeCreatePassword) {
          // Check onboarding before sending to dashboard
          if (!notifier.onboardingComplete) return routeOnboarding;
          return routeDashboard;
        }
        // Block non-chronic members from chronic-only routes.
        // Vitals, medications, lifestyle, and education are now universal.
        if (!notifier.isChronicMember) {
          const chronicRoutes = [
            routeAppointments,
            routeTreatment,
            routeLabResults,
            '/authorizations',
            '/home/chronic',
          ];
          for (final route in chronicRoutes) {
            if (location.startsWith(route)) {
              return routeDashboard;
            }
          }
        }
        // Only redirect to onboarding if still on the onboarding entry points;
        // never force already-navigated authenticated pages back to onboarding.
      }

      return null;
    },
    routes: [
      GoRoute(
        path: routeSplash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: routeLogin,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: routeCreatePassword,
        builder: (_, __) => const CreatePasswordScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeOnboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: routeDashboard,
            builder: (_, __) => const MemberDashboardScreen(),
          ),
          GoRoute(
            path: '/home/chronic',
            builder: (_, __) => const ChronicOnly(
              child: ChronicDashboardScreen(),
            ),
          ),
          GoRoute(
            path: routeVitals,
            builder: (_, __) => const VitalsScreen(),
          ),
          GoRoute(
            path: routeMedications,
            builder: (_, __) => const MedicationsScreen(),
          ),
          GoRoute(
            path: routeAppointments,
            builder: (_, __) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: routeLifestyle,
            builder: (_, __) => const LifestyleScreen(),
          ),
          GoRoute(
            path: routeNotifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: routeProfile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: routeTreatment,
            builder: (_, __) => const TreatmentScreen(),
          ),
          GoRoute(
            path: routeLabResults,
            builder: (_, __) => const LabResultsScreen(),
          ),
          GoRoute(
            path: routeFacilityFinder,
            builder: (_, __) => const FacilityFinderScreen(),
          ),
          GoRoute(
            path: routeEducation,
            builder: (_, __) => const ConditionEducationScreen(),
          ),
          GoRoute(
            path: routeBenefits,
            builder: (_, __) => const BenefitsScreen(),
          ),
          GoRoute(
            path: routeClaims,
            builder: (_, __) => const ClaimsScreen(),
          ),
          GoRoute(
            path: routeDependants,
            builder: (_, __) => const DependantsListScreen(),
          ),
          GoRoute(
            path: routeMembershipCard,
            builder: (_, __) => const MembershipCardScreen(),
          ),
          GoRoute(
            path: routePreauths,
            builder: (_, __) => const PreauthListScreen(),
          ),
          GoRoute(
            path: routeNetwork,
            builder: (_, __) => const NetworkProvidersScreen(),
          ),
        ],
      ),
      // ── Detail / form screens — full-screen, outside the shell ──────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeVitals/log',
        builder: (_, __) => const LogVitalsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeVitals/history',
        builder: (_, __) => const VitalsHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeMedications/add',
        builder: (_, __) => const AddMedicationScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeMedications/:id',
        builder: (_, state) => MedicationDetailScreen(
            id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeAppointments/book',
        builder: (_, __) => const BookAppointmentScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeAppointments/:id',
        builder: (_, state) => AppointmentDetailScreen(
            id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeLogMeal,
        builder: (_, __) => const LogMealScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeLogFitness,
        builder: (_, __) => const LogFitnessScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routePartners,
        builder: (_, state) => PartnerLocatorScreen(
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeProfile/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeProfile/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeProfile/my-provider',
        builder: (_, __) => const MyProviderScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/authorizations',
        builder: (_, __) => const AuthorizationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/authorizations/request',
        builder: (context, state) {
          final extra = state.extra as Map<String, String?>?;
          return RequestAuthorizationScreen(
            medicationId: extra?['medicationId'],
            medicationName: extra?['medicationName'],
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeForgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeVerifyOtp,
        builder: (_, state) => VerifyOtpScreen(
          memberNumber: state.extra as String,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeResetPassword,
        builder: (_, state) => ResetPasswordScreen(
          resetToken: state.extra as String,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: routeEmergencySos,
        builder: (_, __) => const EmergencySosScreen(),
      ),
      // ── Claims detail ──────────────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeClaims/:visitId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final visit = extra?['visit'] as Visit?;
          final memberNo = (extra?['memberNo'] as String?) ?? '';
          return ClaimDetailScreen(
            visitId: state.pathParameters['visitId']!,
            visit: visit,
            memberNo: memberNo,
          );
        },
      ),
      // ── Dependant detail ───────────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routeDependants/:memberNo',
        builder: (_, state) {
          final dep = state.extra as Dependant?;
          final memberNo = Uri.decodeComponent(
              state.pathParameters['memberNo']!);
          return DependantDetailScreen(
            memberNo: memberNo,
            dependant: dep,
          );
        },
      ),
      // ── Preauth detail ─────────────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '$routePreauths/:id',
        builder: (_, state) {
          final preauth = state.extra as Preauth?;
          return PreauthDetailScreen(
            id: state.pathParameters['id']!,
            preauth: preauth,
          );
        },
      ),
    ],
  );
});
