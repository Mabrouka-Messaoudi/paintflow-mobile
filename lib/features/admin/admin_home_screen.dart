import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Temporary admin home — replaced by the clients list in step 5.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حرفائي'),
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
          'مرحباً بك (الدهان)\nقائمة الحرفاء في الخطوة 5',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
