import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/sanlam_api_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/prescription_reminder_service.dart';
import '../core/constants.dart';
import 'onboarding_provider.dart';

enum AuthStatus { loading, authenticated, unauthenticated, needsPassword }

class AuthState {
  final AuthStatus status;
  final Member? member;
  final String? error;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.member,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    Member? member,
    String? error,
    bool? isLoading,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        member: member ?? this.member,
        error: clearError ? null : error,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;
  final Ref _ref;

  AuthNotifier(this._service, this._ref)
      : super(const AuthState(status: AuthStatus.loading)) {
    _initialize();
    // Auto-logout when the server signals a 401 on a protected route.
    sessionExpiredStream.stream.listen((_) {
      if (state.status == AuthStatus.authenticated ||
          state.status == AuthStatus.needsPassword) {
        logout();
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final loggedIn = await _service.isLoggedIn();
      if (loggedIn) {
        final token = await _service.getToken();
        if (token != null && token.isNotEmpty) {
          Member? member = await _service.loadMember();
          member ??= _service.decodeTokenMember(token);
          await _restoreOnboardingState(member?.id);
          state = AuthState(
            status: AuthStatus.authenticated,
            member: member,
          );
          currentSanlamToken = await readSanlamToken();
          if (currentSanlamToken == null && member?.accessToken != null) {
            currentSanlamToken = member!.accessToken;
          }
          _fetchAndUpdateProfile();
          // Always re-check chronic enrolment from local backend on startup
          // so returning chronic members keep their chronic modules.
          _fetchChronicStatus(member?.memberNumber ?? '');
          _registerFcmToken();
          _scheduleMedicationReminders();
          return;
        }
      }
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _restoreOnboardingState(String? memberId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = (memberId != null && memberId.isNotEmpty
              ? prefs.getBool('onboarding_$memberId')
              : null) ??
          prefs.getBool('onboarding_complete') ??
          false;
      _ref.read(onboardingCompleteProvider.notifier).state = done;
    } catch (_) {}
  }

  Future<void> loginWithBiometrics()async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await biometricService.authenticateDetailed();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ??
              'Biometric authentication failed. Please try again.',
        );
        return;
      }
      final creds = await biometricService.getCredentials();
      if (creds == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No saved credentials found. Please sign in with your member number first.',
        );
        return;
      }

      // Connectivity pre-check — resolve the app's own server hostname
      try {
        final uri = Uri.parse(kBaseUrl);
        final result = await InternetAddress.lookup(uri.host)
            .timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            error: 'No internet connection. Please check your network and try again.',
          );
          return;
        }
      } on SocketException {
        state = state.copyWith(
          isLoading: false,
          error: 'No internet connection. Please check your network and try again.',
        );
        return;
      } on TimeoutException {
        state = state.copyWith(
          isLoading: false,
          error: 'No internet connection. Please check your network and try again.',
        );
        return;
      }

      // Network login with retry (up to 2 attempts) — must use the same
      // backend path as the regular login flow.
      const useLegacy =
          bool.fromEnvironment('USE_LEGACY_AUTH', defaultValue: false);
      Object? lastError;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          if (useLegacy) {
            final data = await _service.loginWithMemberNumber(
                creds.memberNumber, creds.password);
            await _handleLoginResponse(data);
          } else {
            final member = await _service.loginSanlam(
                creds.memberNumber, creds.password);
            await _handleSanlamMemberResponse(member);
          }
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt == 1) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (lastError != null) throw lastError;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> loginWithMemberNumber(
      String memberNumber, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      const useLegacy = bool.fromEnvironment('USE_LEGACY_AUTH', defaultValue: false);
      if (useLegacy) {
        final data =
            await _service.loginWithMemberNumber(memberNumber, password);
        await _handleLoginResponse(data);
      } else {
        final member = await _service.loginSanlam(memberNumber, password);
        await _handleSanlamMemberResponse(member);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> loginWithDOB(
      String lastName, String dob, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.loginWithDOB(lastName, dob, password);
      await _handleLoginResponse(data);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> _handleLoginResponse(Map<String, dynamic> data) async {
    final token = (data['token'] ?? data['access_token'] ?? '').toString();
    if (token.isNotEmpty) {
      await _service.saveToken(token);
    }

    Member? member;
    final memberData = data['member'];
    final memberJson = memberData != null
        ? Map<String, dynamic>.from(memberData as Map)
        : null;
    if (memberJson != null) {
      member = Member.fromJson(memberJson);
    } else if (token.isNotEmpty) {
      member = _service.decodeTokenMember(token);
    }

    final needsPassword =
        (data['requires_password_setup'] as bool? ?? false) ||
            (member != null && !member.isPasswordSet);

    if (needsPassword) {
      state = AuthState(
        status: AuthStatus.needsPassword,
        member: member,
        isLoading: false,
      );
    } else {
      // Restore per-user onboarding state BEFORE setting authenticated so the
      // router redirect sees the correct value and doesn't send returning users
      // to onboarding on every login.
      await _restoreOnboardingState(member?.id);

      state = AuthState(
        status: AuthStatus.authenticated,
        member: member,
        isLoading: false,
      );
      // Fetch full profile in background to load conditions
      _fetchAndUpdateProfile();
      // Also resolve chronic enrolment from the local backend so the legacy
      // login path lights up chronic modules for returning chronic members.
      _fetchChronicStatus(member?.memberNumber ?? '');
      // Register FCM token with backend
      _registerFcmToken();
      // Schedule local medication reminders
      _scheduleMedicationReminders();
    }
  }

  Future<void> _handleSanlamMemberResponse(Member member) async {
    // Stash the Sanlam JWT for the Sanlam API client
    currentSanlamToken = member.accessToken;

    await _restoreOnboardingState(member.id);

    state = AuthState(
      status: AuthStatus.authenticated,
      member: member,
      isLoading: false,
    );

    // Background: fetch chronic status from our own backend
    _fetchChronicStatus(member.memberNumber);

    _registerFcmToken();
    _scheduleMedicationReminders();
  }

  Future<void> _fetchChronicStatus(String memberNumber) async {
    try {
      final response = await dio.get('/me/chronic-status');
      final isChronic =
          (response.data as Map?)?['isChronic'] as bool? ?? false;
      if (state.member != null) {
        final updated = state.member!.copyWith(isChronic: isChronic);
        state = state.copyWith(member: updated);
        // Persist so cold-start sees the right value before the next call.
        try {
          await _service.saveMember(updated);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _fetchAndUpdateProfile() async {
    try {
      final response = await dio.get('/members/me');
      final memberJson = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map);
      // Preserve the locally-known chronic flag if the API response doesn't
      // include one — protects against the value being clobbered to false
      // by older endpoints.
      // Never let /members/me downgrade the chronic flag we already know.
      final prev = state.member;
      if (prev != null && prev.isChronic) {
        final raw = memberJson['is_chronic'] ?? memberJson['isChronic'];
        final freshChronic = raw == true ||
            raw == 1 ||
            raw?.toString().toLowerCase() == 'true';
        if (!freshChronic) memberJson['is_chronic'] = true;
      } else if (!memberJson.containsKey('is_chronic') &&
          !memberJson.containsKey('isChronic') &&
          prev != null) {
        memberJson['is_chronic'] = prev.isChronic;
      }
      final fresh = Member.fromJson(memberJson);
      // Preserve Sanlam-sourced fields (schemeName/planCode/name/relation/
      // tokens) that /members/me doesn't carry. Without this, the Profile
      // screen loses scheme + plan + correct name on every cold start.
      String? keep(String? n, String? o) =>
          (n == null || n.trim().isEmpty) ? o : n;
      final updatedMember = prev == null
          ? fresh
          : fresh.copyWith(
              firstName:
                  fresh.firstName.trim().isNotEmpty ? fresh.firstName : prev.firstName,
              lastName:
                  fresh.lastName.trim().isNotEmpty ? fresh.lastName : prev.lastName,
              schemeName: keep(fresh.schemeName, prev.schemeName),
              planCode: keep(fresh.planCode, prev.planCode),
              planType: keep(fresh.planType, prev.planType),
              relation: keep(fresh.relation, prev.relation),
              email: keep(fresh.email, prev.email),
              phone: keep(fresh.phone, prev.phone),
              profileIcon: fresh.profileIcon ?? prev.profileIcon,
              accessToken: fresh.accessToken ?? prev.accessToken,
              tokenExp: fresh.tokenExp ?? prev.tokenExp,
            );
      state = state.copyWith(member: updatedMember);
      try {
        await _service.saveMember(updatedMember);
      } catch (_) {}
    } catch (_) {}
  }

  /// Send the FCM device token to the backend so push notifications can reach this device.
  Future<void> _registerFcmToken() async {
    try {
      final token = await NotificationService.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await dio.put('/members/me', data: {'fcm_token': token});
      }
    } catch (_) {}
  }

  /// Fetch the user's medications and schedule local notifications as a reliable fallback.
  Future<void> _scheduleMedicationReminders() async {
    try {
      final response = await dio.get('/medications/member/mine');
      final meds = response.data as List? ?? [];
      await NotificationService.cancelAll();
      int notifId = 5000;
      for (final med in meds) {
        final enabled = med['reminder_enabled'] ?? false;
        if (!enabled) continue;
        final name = med['medication_name'] ?? med['name'] ?? 'medication';
        final times = med['times'] as List? ?? [];
        for (final t in times) {
          final parts = t.toString().split(':');
          if (parts.length >= 2) {
            final hour = int.tryParse(parts[0]) ?? 0;
            final minute = int.tryParse(parts[1]) ?? 0;
            await NotificationService.scheduleMedicationReminder(
              id: notifId++,
              medicationName: name.toString(),
              hour: hour,
              minute: minute,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> createPassword(
      String password, String confirmPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.createPassword(password, confirmPassword);
      final updated = state.member?.copyWith(isPasswordSet: true);
      state = AuthState(
        status: AuthStatus.authenticated,
        member: updated,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.changePassword(currentPassword, newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  /// After 15 minutes in the background, automatically log the user out.
  static const _inactivityTimeout = Duration(minutes: 15);
  Timer? _inactivityTimer;
  DateTime? _backgroundedAt;

  /// Call when the app goes to background (paused).
  void onAppPaused() {
    _backgroundedAt = DateTime.now();
  }

  /// Call when the app returns to foreground (resumed).
  void onAppResumed() {
    if (_backgroundedAt != null &&
        DateTime.now().difference(_backgroundedAt!) >= _inactivityTimeout &&
        (state.status == AuthStatus.authenticated ||
            state.status == AuthStatus.needsPassword)) {
      logout();
    }
    _backgroundedAt = null;
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } catch (_) {}
    try {
      await PrescriptionReminderService.clear();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateMember(Member member) {
    // Defensive: never downgrade isChronic from true → false within a session.
    // Some endpoints (e.g. partial profile updates) can return responses where
    // the chronic flag isn't authoritative. Allowing them to flip the flag to
    // false caused the Chronic Dashboard route to be redirected away (blank
    // screen) after the user opened Profile, since Profile triggers async
    // syncs that hit those endpoints.
    final prev = state.member;
    final next = (prev != null && prev.isChronic && !member.isChronic)
        ? member.copyWith(isChronic: true)
        : member;
    state = state.copyWith(member: next);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid username') ||
        msg.contains('invalid/password') ||
        msg.contains('sanlamapiexception')) {
      return 'Invalid member number or password.';
    }
    if (msg.contains('401') ||
        msg.contains('invalid') ||
        msg.contains('credentials') ||
        msg.contains('unauthorized')) {
      return 'Invalid credentials. Please check your details.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('connection') ||
        msg.contains('network')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('404')) {
      return 'Member not found. Please check your details.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(authService, ref);
});
