import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sign-in / sign-out and the current user's role ('admin' or 'client').
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? _role;

  static bool get isSignedIn => _client.auth.currentSession != null;

  static Future<String> role() async {
    if (_role != null) return _role!;
    final uid = _client.auth.currentUser!.id;
    final row =
        await _client.from('profiles').select('role').eq('id', uid).single();
    return _role = row['role'] as String;
  }

  static Future<void> signIn(String email, String password) async {
    _role = null;
    await _client.auth.signInWithPassword(email: email, password: password);
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
