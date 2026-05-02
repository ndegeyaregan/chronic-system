// Web stub — biometrics not supported on web.
// All methods return safe no-op values.

enum BiometricType { face, fingerprint, iris, strong, weak }

class BiometricAuthResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  const BiometricAuthResult(this.success,
      {this.errorCode, this.errorMessage});
}

class BiometricImpl {
  Future<bool> isAvailable() async => false;
  Future<List<BiometricType>> availableTypes() async => [];
  Future<bool> authenticate() async => false;
  Future<BiometricAuthResult> authenticateDetailed() async =>
      const BiometricAuthResult(false,
          errorMessage: 'Biometric login is not supported on this platform.');
}
