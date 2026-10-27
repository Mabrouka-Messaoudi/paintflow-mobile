import 'package:flutter/material.dart';

/// Temporary project screen — replaced by the real one in step 6.
class ClientDetailPlaceholder extends StatelessWidget {
  const ClientDetailPlaceholder({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشروع')),
      body: Center(
        child: Text(
          'صفحة المشروع في الخطوة 6\n$clientId',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
