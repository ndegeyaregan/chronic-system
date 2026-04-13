import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
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
          final member = _service.decodeTokenMember(token);
          // Restore onboarding state before setting authenticated so the
          // router redirect sees the correct value immediately.
          await _restoreOnboardingState(member?.id);
          state = AuthState(
            status: AuthStatus.authenticated,
            member: member,
          );
          // Fetch full profile in background to get conditions
          _fetchAndUpdateProfile();
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
      final authed = await biometricService.authenticate();
      if (!authed) {
        state = state.copyWith(
          isLoading: false,
          error: 'Biometric authentication failed. Please try again.',
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
      final data = await _service.loginWithMemberNumber(creds.memberNumber, creds.password);
      await _handleLoginResponse(data);
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
      final data =
          await _service.loginWithMemberNumber(memberNumber, password);
      await _handleLoginResponse(data);
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
    }
  }

  Future<void> _fetchAndUpdateProfile() async {
    try {
      final response = await dio.get('/members/me');
      final memberJson = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map);
      final updatedMember = Member.fromJson(memberJson);
      state = state.copyWith(member: updatedMember);
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
    await _service.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateMember(Member member) {
    state = state.copyWith(member: member);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
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
