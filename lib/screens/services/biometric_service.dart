import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keyBiometricsEnabled = 'biometrics_enabled';
  static const String _keySavedRegNo = 'biometrics_reg_no';
  static const String _keySavedPassword = 'biometrics_password';
  static const String _keySavedName = 'biometrics_name';

  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to access Commutas',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricsEnabled) ?? false;
  }

  Future<bool> enableBiometrics({
    required String regNo,
    required String password,
    required String name,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBiometricsEnabled, true);
      await _secureStorage.write(key: _keySavedRegNo, value: regNo);
      await _secureStorage.write(key: _keySavedPassword, value: password);
      await _secureStorage.write(key: _keySavedName, value: name);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricsEnabled, false);
    await _secureStorage.delete(key: _keySavedRegNo);
    await _secureStorage.delete(key: _keySavedPassword);
    await _secureStorage.delete(key: _keySavedName);
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyBiometricsEnabled) ?? false;
    if (!enabled) return null;
    final regNo = await _secureStorage.read(key: _keySavedRegNo);
    final password = await _secureStorage.read(key: _keySavedPassword);
    final name = await _secureStorage.read(key: _keySavedName) ?? '';
    if (regNo != null && password != null) {
      return {
        'reg_no': regNo,
        'password': password,
        'name': name,
      };
    }
    return null;
  }
}

