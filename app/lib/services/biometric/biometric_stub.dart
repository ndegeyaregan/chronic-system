// Web stub — biometrics not supported on web.
// All methods return safe no-op values.

enum BiometricType { face, fingerprint, iris, strong, weak }

class BiometricImpl {
  Future<bool> isAvailable() async => false;
  Future<List<BiometricType>> availableTypes() async => [];
  Future<bool> authenticate() async => false;
}
