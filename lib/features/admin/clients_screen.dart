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
import 'add_client_sheet.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  String _query = '';
  ClientStatus? _filter; // null = all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ClientSummary> _apply(List<ClientSummary> all) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      if (_filter != null && c.status != _filter) return false;
      if (q.isEmpty) return true;
      return c.fullName.toLowerCase().contains(q) ||
          (c.address ?? '').toLowerCase().contains(q) ||
          (c.phone ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final all = clients.value ?? const <ClientSummary>[];

    return Scaffold(
      body: Column(
        children: [
          _Header(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          _FilterChips(
            all: all,
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          Expanded(
            child: clients.when(
              loading: () => const _SkeletonList(),
              error: (e, _) =>
                  _ErrorView(onRetry: () => ref.invalidate(clientsProvider)),
              data: (list) {
                final visible = _apply(list);
                return RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: () => ref.refresh(clientsProvider.future),
                  child: visible.isEmpty
                      ? _EmptyView(isFiltered: list.isNotEmpty)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final c = visible[i];
                            return KeyedSubtree(
                              key: ValueKey(c.id),
                              child: ClientCard(
                                client: c,
                                onTap: () =>
                                    context.push('/admin/clients/${c.id}',
                                        extra: c),
                              )
                                  .animate(delay: (70 * i.clamp(0, 8)).ms)
                                  .fadeIn(duration: 450.ms)
                                  .slideY(
                                      begin: 0.12,
                                      end: 0,
                                      duration: 550.ms,
                                      curve: Curves.easeOutCubic),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddClientSheet(context),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('حريف جديد',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      )
          .animate(delay: 500.ms)
          .fadeIn()
          .scale(
              begin: const Offset(0.6, 0.6),
              duration: 600.ms,
              curve: Curves.easeOutBack),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const hint = Color(0xFFA9B4C6);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c),
        );

    return NavyHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مرحباً بك',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14, color: hint)),
                    Text('حرفائي',
                        style: GoogleFonts.cairo(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3)),
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: AppColors.amber,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث عن حريف أو مكان…',
                hintStyle: const TextStyle(color: hint),
                prefixIcon: const Icon(Icons.search_rounded, color: hint),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close_rounded, color: hint),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: border(Colors.white.withValues(alpha: 0.14)),
                focusedBorder: border(AppColors.amber.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips(
      {required this.all, required this.selected, required this.onSelected});

  final List<ClientSummary> all;
  final ClientStatus? selected;
  final ValueChanged<ClientStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        children: [
          _Chip(
            label: 'الكل · ${all.length}',
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final s in ClientStatus.values)
            _Chip(
              label: '${s.label} · ${all.where((c) => c.status == s).length}',
              active: selected == s,
              onTap: () => onSelected(s),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: 300.ms,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: active ? AppColors.navy : const Color(0xFFE0E4EA)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF344054),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClientCard extends StatelessWidget {
  const ClientCard({super.key, required this.client, required this.onTap});

  final ClientSummary client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = client;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDF0F4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'avatar-${c.id}',
                  child: ClientAvatar(id: c.id, name: c.fullName),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if ((c.address ?? '').isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(c.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                StatusPill(status: c.status),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedProgressBar(value: c.progress),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'المتفق عليه', value: money(c.agreedAmount)),
                _Stat(
                    label: 'المستلم',
                    value: money(c.received),
                    color: AppColors.tealDark),
                _Stat(
                  label: 'المتبقي',
                  value: money(c.remaining),
                  color: c.remaining <= 0 ? AppColors.tealDark : AppColors.orange,
                  bold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      this.color = AppColors.ink,
      this.bold = false});

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: 400.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: const Color(0xFFEEF0F4)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Icon(
          isFiltered ? Icons.search_off_rounded : Icons.groups_2_outlined,
          size: 64,
          color: AppColors.muted.withValues(alpha: 0.5),
        ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
        const SizedBox(height: 16),
        Text(
          isFiltered ? 'لا توجد نتائج' : 'لا يوجد حرفاء بعد',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          isFiltered
              ? 'جرّب كلمة بحث أخرى أو فلتراً آخر'
              : 'اضغط على «حريف جديد» لإضافة أول حريف',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('تعذّر تحميل الحرفاء',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('تحقّق من الإنترنت ثم أعد المحاولة',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
