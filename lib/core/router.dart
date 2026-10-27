import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_home_screen.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/client/client_home_screen.dart';
import 'app_theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthRefresh(),
  redirect: (context, state) async {
    final location = state.matchedLocation;

    if (!AuthService.isSignedIn) {
      return location == '/login' ? null : '/login';
    }

    final String role;
    try {
      role = await AuthService.role();
    } catch (_) {
      await AuthService.signOut();
      return '/login';
    }

    final home = role == 'admin' ? '/admin' : '/client';
    if (location == '/' || location == '/login') return home;
    if (location.startsWith('/admin') && role != 'admin') return '/client';
    if (location.startsWith('/client') && role == 'admin') return '/admin';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
    GoRoute(path: '/client', builder: (context, state) => const ClientHomeScreen()),
  ],
);

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      ),
    );
  }
}
