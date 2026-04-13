// ignore_for_file: unnecessary_non_null_assertion
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import: loads local_auth on mobile, stub on web
import 'biometric/biometric_stub.dart'
    if (dart.library.io) 'biometric/biometric_mobile.dart';

export 'biometric/biometric_stub.dart'
    if (dart.library.io) 'biometric/biometric_mobile.dart' show BiometricType;

const _kBiometricEnabled = 'biometric_enabled';
const _kBiometricMemberNumber = 'biometric_member_number';
const _kBiometricPassword = 'biometric_password';

class BiometricService {
  final _impl = BiometricImpl();
  final _storage = kIsWeb ? null : const FlutterSecureStorage();

  Future<bool> isAvailable() => _impl.isAvailable();

  Future<List<BiometricType>> availableTypes() => _impl.availableTypes();

  Future<bool> isEnabled() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kBiometricEnabled) ?? false;
    }
    final val = await _storage!.read(key: _kBiometricEnabled);
    return val == 'true';
  }

  Future<bool> authenticate() => _impl.authenticate();

  Future<void> saveCredentials(String memberNumber, String password) async {
    if (kIsWeb) return;
    await _storage!.write(key: _kBiometricEnabled, value: 'true');
    await _storage!.write(key: _kBiometricMemberNumber, value: memberNumber);
    await _storage!.write(key: _kBiometricPassword, value: password);
  }

  Future<({String memberNumber, String password})?> getCredentials() async {
    if (kIsWeb) return null;
    final memberNumber = await _storage!.read(key: _kBiometricMemberNumber);
    final password = await _storage!.read(key: _kBiometricPassword);
    if (memberNumber == null || password == null) return null;
    return (memberNumber: memberNumber, password: password);
  }

  Future<void> disable() async {
    if (kIsWeb) return;
    await _storage!.delete(key: _kBiometricEnabled);
    // Keep credentials stored so user can re-enable from profile without re-logging in
  }
}

final biometricService = BiometricService();
