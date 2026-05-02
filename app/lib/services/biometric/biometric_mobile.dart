// Mobile implementation using local_auth.
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

export 'package:local_auth/local_auth.dart' show BiometricType;

class BiometricAuthResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  const BiometricAuthResult(this.success,
      {this.errorCode, this.errorMessage});
}

class BiometricImpl {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<BiometricAuthResult> authenticateDetailed() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Verify your identity to sign in',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'SanCare+',
            biometricHint: '',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(cancelButton: 'Cancel'),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return BiometricAuthResult(ok,
          errorMessage: ok ? null : 'Authentication was cancelled.');
    } on PlatformException catch (e) {
      return BiometricAuthResult(false,
          errorCode: e.code, errorMessage: _humanizeError(e));
    } catch (e) {
      return BiometricAuthResult(false, errorMessage: e.toString());
    }
  }

  Future<bool> authenticate() async =>
      (await authenticateDetailed()).success;

  String _humanizeError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric hardware is not available on this device.';
      case 'NotEnrolled':
        return 'No fingerprints or face data enrolled. Set up biometrics in your device settings, then try again.';
      case 'PasscodeNotSet':
        return 'Set a screen lock (PIN, pattern or password) on your device, then try again.';
      case 'LockedOut':
        return 'Too many failed attempts. Wait a moment and try again.';
      case 'PermanentlyLockedOut':
        return 'Biometric login is locked. Unlock your device with your PIN/password to re-enable it.';
      case 'no_fragment_activity':
        return 'App needs to be restarted to enable biometric login.';
      case 'auth_in_progress':
        return 'A biometric prompt is already showing. Please wait.';
      default:
        return e.message ?? 'Biometric authentication failed (${e.code}).';
    }
  }
}
