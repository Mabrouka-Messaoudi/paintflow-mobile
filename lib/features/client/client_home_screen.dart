import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Temporary client home — replaced by the project view later.
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حضيرتي'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: AuthService.signOut,
          ),
        ],
      ),
      body: Center(
        child: Text(
          'مرحباً بك (الحريف)\nتفاصيل حضيرتك ستظهر هنا',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
