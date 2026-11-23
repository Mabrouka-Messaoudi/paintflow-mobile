import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../../data/client_summary.dart';
import '../../data/clients_repository.dart';
import '../auth/auth_service.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider).value ?? const <ClientSummary>[];
    final inProgress =
        clients.where((c) => c.status == ClientStatus.progress).length;
    final remaining = clients.fold<double>(0, (s, c) => s + c.remaining);

    return Scaffold(
      body: Column(
        children: [
          NavyHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مرحباً بك في',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14,
                                  color: const Color(0xFFA9B4C6))),
                          Text('مكتبك',
                              style: GoogleFonts.cairo(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.3)),
                          Text('مكتبك الرقمي لإدارة أعمالك',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  color: const Color(0xFFA9B4C6))),
                          const SizedBox(height: 8),
                          Container(
                            width: 56,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ).animate().scaleX(
                              begin: 0,
                              end: 1,
                              alignment: Alignment.centerRight,
                              duration: 700.ms,
                              curve: Curves.easeOutCubic),
                        ],
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'تسجيل الخروج',
                      onPressed: AuthService.signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatChip(label: 'المشاريع', value: '${clients.length}'),
                    const SizedBox(width: 10),
                    _StatChip(label: 'قيد الإنجاز', value: '$inProgress'),
                    const SizedBox(width: 10),
                    _StatChip(
                        label: 'المتبقي',
                        value: money(remaining),
                        highlight: true),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('مساحة عملك',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _ServiceCard(
                  icon: Icons.format_paint_outlined,
                  gradient: const [AppColors.teal, AppColors.tealDark],
                  title: 'المشاريع',
                  subtitle: 'متابعة الأشغال ومراحل التنفيذ',
                  badge: clients.isEmpty ? null : '${clients.length}',
                  onTap: () => context.push('/admin/clients'),
                )
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                const SizedBox(height: 14),
                _ServiceCard(
                  icon: Icons.account_balance_wallet_outlined,
                  gradient: const [AppColors.amber, Color(0xFFD97706)],
                  title: 'المقبوضات',
                  subtitle: 'المقبوضات، السلع، المصاريف وأجور العمال',
                  onTap: () => context.push('/admin/finance'),
                )
                    .animate(delay: 120.ms)
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.12, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFA9B4C6))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.amber : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEDF0F4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.cairo(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDark)),
              ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
