import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../auth/auth_service.dart';
import '../project/project_screen.dart';

/// The client's own project id (linked through clients.user_id).
final myClientIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final row = await db
      .from('clients')
      .select('id')
      .eq('user_id', uid)
      .maybeSingle();
  return row?['id'] as String?;
});

/// Client home = their project, read-only and live.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myClientIdProvider);

    return myId.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      ),
      error: (e, _) => _Message(
        icon: Icons.wifi_off_rounded,
        title: 'تعذّر تحميل الشانطي',
        subtitle: 'تحقّق من الإنترنت ثم أعد المحاولة',
        onRetry: () => ref.invalidate(myClientIdProvider),
      ),
      data: (id) => id == null
          ? const _Message(
              icon: Icons.link_off_rounded,
              title: 'حسابك غير مربوط بأي شانطي',
              subtitle: 'تواصل مع الدهان ليربط حسابك بالشانطي',
            )
          : ProjectScreen(clientId: id, readOnly: true),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              if (onRetry != null) ...[
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
                const SizedBox(height: 10),
              ],
              TextButton.icon(
                onPressed: AuthService.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
