import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sign-in / sign-out, "remember me" and the current user's role.
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? _role;
  static late SharedPreferences _prefs;

  static const _kRemember = 'remember_me';
  static const _kEmail = 'saved_email';

  /// Call once at startup, after Supabase.initialize.
  /// Without "remember me", the previous session ends when the app restarts.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final remember = _prefs.getBool(_kRemember) ?? true;
    if (!remember && _client.auth.currentSession != null) {
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }

  static bool get rememberMe => _prefs.getBool(_kRemember) ?? true;
  static String? get savedEmail => _prefs.getString(_kEmail);

  static bool get isSignedIn => _client.auth.currentSession != null;

  static Future<String> role() async {
    if (_role != null) return _role!;
    final uid = _client.auth.currentUser!.id;
    final row =
        await _client.from('profiles').select('role').eq('id', uid).single();
    return _role = row['role'] as String;
  }

  static Future<void> signIn(String email, String password,
      {bool remember = true, bool enableBiometrics = false}) async {
    _role = null;
    await _client.auth.signInWithPassword(email: email, password: password);
    await _prefs.setBool(_kRemember, remember);
    if (remember) {
      await _prefs.setString(_kEmail, email);
    } else {
      await _prefs.remove(_kEmail);
    }
    if (enableBiometrics) {
      // Encrypted with the Android Keystore / iOS Keychain.
      await _secure.write(key: _kBioEmail, value: email);
      await _secure.write(key: _kBioPassword, value: password);
    }
  }

  /// True right after the user pressed "logout" (no automatic fingerprint
  /// prompt in that case, only on a fresh app start).
  static bool justSignedOut = false;

  static Future<void> signOut() async {
    _role = null;
    justSignedOut = true;
    await _client.auth.signOut();
  }

  // ---------- Fingerprint login ----------

  static const _secure = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();
  static const _kBioEmail = 'bio_email';
  static const _kBioPassword = 'bio_password';

  /// The phone has a fingerprint (or other biometric) set up.
  static Future<bool> biometricsAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> biometricEmail() async {
    try {
      return await _secure.read(key: _kBioEmail);
    } catch (_) {
      return null;
    }
  }

  static Future<void> disableBiometrics() async {
    await _secure.delete(key: _kBioEmail);
    await _secure.delete(key: _kBioPassword);
  }

  /// Asks for the fingerprint, then signs in with the saved credentials.
  /// Returns false if the user cancelled.
  static Future<bool> signInWithBiometrics() async {
    final ok = await _localAuth.authenticate(
      localizedReason: 'ضع إصبعك لتسجيل الدخول إلى PaintFlow',
    );
    if (!ok) return false;

    final email = await _secure.read(key: _kBioEmail);
    final password = await _secure.read(key: _kBioPassword);
    if (email == null || password == null) return false;

    try {
      await signIn(email, password, remember: rememberMe);
    } on AuthException {
      // Password changed since it was saved: forget it.
      await disableBiometrics();
      rethrow;
    }
    return true;
  }
}

/// Tells the router to re-check redirects whenever the auth state changes.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
