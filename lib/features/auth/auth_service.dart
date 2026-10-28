import 'dart:async';

import 'package:flutter/foundation.dart';
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
      {bool remember = true}) async {
    _role = null;
    await _client.auth.signInWithPassword(email: email, password: password);
    await _prefs.setBool(_kRemember, remember);
    if (remember) {
      await _prefs.setString(_kEmail, email);
    } else {
      await _prefs.remove(_kEmail);
    }
  }

  static Future<void> signOut() async {
    _role = null;
    await _client.auth.signOut();
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
