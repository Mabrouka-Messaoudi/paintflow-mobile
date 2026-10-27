import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../../data/client_summary.dart';
import '../../data/payment.dart';
import '../../data/project_repository.dart';
import '../../data/purchase.dart';
import '../auth/auth_service.dart';
import 'add_payment_sheet.dart';
import 'add_purchase_sheet.dart';
import 'purchase_widgets.dart';

/// One client's project: amounts, payments and (later) purchases.
/// [readOnly] = the client's own view (no add / delete).
class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({
    super.key,
    required this.clientId,
    this.initial,
    this.readOnly = false,
  });

  final String clientId;
  final ClientSummary? initial;
  final bool readOnly;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  int _tab = 0;
  final _hidden = <String>{}; // payments removed optimistically

  Future<bool> _confirmDelete(BuildContext context,
      {required String title, required String message}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deletePayment(Payment p) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(p.id));
    try {
      await ref.read(projectRepositoryProvider).deletePayment(p.id);
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تم حذف الدفعة'),
      ));
    } catch (_) {
      if (mounted) setState(() => _hidden.remove(p.id));
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تعذّر حذف الدفعة'),
      ));
    }
  }

  Future<void> _deletePurchase(Purchase p) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(p.id));
    try {
      await ref.read(projectRepositoryProvider).deletePurchase(p);
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تم حذف الشراء'),
      ));
    } catch (_) {
      if (mounted) setState(() => _hidden.remove(p.id));
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تعذّر حذف الشراء'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectProvider(widget.clientId));
    final data = async.value ??
        (widget.initial == null
            ? null
            : ProjectData(widget.initial!, const [], const [], const {}));
    final loadingPayments = async.value == null && !async.hasError;

    if (data == null) {
      return Scaffold(
        body: async.hasError
            ? _ErrorBody(
                onRetry: () =>
                    ref.invalidate(projectProvider(widget.clientId)))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final payments =
        data.payments.where((p) => !_hidden.contains(p.id)).toList();
    final purchases =
        data.purchases.where((p) => !_hidden.contains(p.id)).toList();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: _Top(client: data.client, readOnly: widget.readOnly),
          ),
          SliverToBoxAdapter(
            child: _Tabs(
              index: _tab,
              paymentsCount: payments.length,
              purchasesCount: purchases.length,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          if (_tab == 0)
            ..._paymentSlivers(payments, loadingPayments)
          else
            ..._purchaseSlivers(purchases, data.imageUrls, loadingPayments),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : _BottomBar(
              label: _tab == 0 ? 'إضافة دفعة' : 'إضافة شراء',
              onPressed: () => _tab == 0
                  ? showAddPaymentSheet(context, data.client)
                  : showAddPurchaseSheet(context, data.client),
            ),
    );
  }

  List<Widget> _paymentSlivers(List<Payment> payments, bool loading) {
    if (loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1200.ms, color: const Color(0xFFEEF0F4)),
          ),
        ),
      ];
    }

    if (payments.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Column(
              children: [
                Icon(Icons.payments_outlined,
                    size: 56, color: AppColors.muted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('لا توجد دفعات بعد',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  widget.readOnly
                      ? 'ستظهر هنا كل دفعة يسجّلها الدهان'
                      : 'اضغط على «إضافة دفعة» لتسجيل أول مبلغ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ),
      ];
    }

    return [
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text('سجل الدفعات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: payments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = payments[i];
            final tile =
                _PaymentTile(payment: p, number: payments.length - i);
            final Widget child = widget.readOnly
                ? tile
                : Dismissible(
                    key: ValueKey(p.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(
                      context,
                      title: 'حذف الدفعة؟',
                      message:
                          'سيتم حذف ${money(p.amount)} وتحديث المبلغ المستلم والمتبقي.',
                    ),
                    onDismissed: (_) => _deletePayment(p),
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE4E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFB42318)),
                    ),
                    child: tile,
                  );
            return KeyedSubtree(
              key: ValueKey('pay-${p.id}'),
              child: child
                  .animate(delay: (60 * i.clamp(0, 8)).ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _purchaseSlivers(
      List<Purchase> purchases, Map<String, String> urls, bool loading) {
    if (loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1200.ms, color: const Color(0xFFEEF0F4)),
          ),
        ),
      ];
    }

    if (purchases.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: AppColors.muted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('لا توجد مشتريات بعد',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  widget.readOnly
                      ? 'ستظهر هنا مشتريات الدهان مع صور الفواتير'
                      : 'اضغط على «إضافة شراء» لتسجيل أول فاتورة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ),
      ];
    }

    final total = purchases.fold<double>(0, (s, p) => s + p.total);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Expanded(
                child: Text('قائمة المشتريات',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('المجموع: ${money(total)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF78350F))),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: purchases.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = purchases[i];
            final tile = PurchaseTile(purchase: p, urls: urls);
            final Widget child = widget.readOnly
                ? tile
                : Dismissible(
                    key: ValueKey(p.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(
                      context,
                      title: 'حذف هذا الشراء؟',
                      message:
                          'سيتم حذف «${p.itemName}» (${money(p.total)}) مع صوره.',
                    ),
                    onDismissed: (_) => _deletePurchase(p),
                    background: deleteBackground(),
                    child: tile,
                  );
            return KeyedSubtree(
              key: ValueKey('buy-${p.id}'),
              child: child
                  .animate(delay: (60 * i.clamp(0, 8)).ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic),
            );
          },
        ),
      ),
    ];
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.client, required this.readOnly});

  final ClientSummary client;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final c = client;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top + 176,
          child: NavyHeader(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                readOnly
                    ? GlassIconButton(
                        icon: Icons.logout_rounded,
                        tooltip: 'تسجيل الخروج',
                        onPressed: AuthService.signOut,
                      )
                    : GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'رجوع',
                        onPressed: () => context.pop(),
                      ),
                const SizedBox(width: 12),
                Hero(
                  tag: 'avatar-${c.id}',
                  child: ClientAvatar(id: c.id, name: c.fullName, size: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (readOnly)
                        const Text('مرحباً',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFFA9B4C6))),
                      Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3),
                      ),
                      if ((c.address ?? '').isNotEmpty)
                        Text(
                          c.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFA9B4C6)),
                        ),
                      const SizedBox(height: 6),
                      StatusPill(status: c.status),
                    ],
                  ),
                ),
                if (!readOnly && (c.phone ?? '').isNotEmpty)
                  Material(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      tooltip: 'اتصال بالحريف',
                      icon: const Icon(Icons.call_rounded,
                          color: AppColors.navy),
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: c.phone)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 116, 16, 0),
          child: _SummaryCard(client: c)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(
                  begin: 0.12,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.client});

  final ClientSummary client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    String fmt(double v) => money(v.round());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Ring(progress: c.progress),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المبلغ المتفق عليه',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.muted)),
                    CountUpText(
                      value: c.agreedAmount,
                      format: fmt,
                      style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AmountTile(
                  label: 'المستلم',
                  value: c.received,
                  bg: AppColors.tealSoft,
                  fg: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountTile(
                  label: 'المتبقي',
                  value: c.remaining,
                  bg: AppColors.orangeSoft,
                  fg: AppColors.orange,
                ),
              ),
            ],
          ),
          if (c.purchasesTotal > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text('مصاريف المشتريات: ${money(c.purchasesTotal)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: 1400.ms,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Semantics(
        label: 'تم دفع ${(v * 100).round()} بالمائة',
        child: SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                backgroundColor: const Color(0xFFEEF0F4),
                color: const Color(0xFF0E7A6E),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(v * 100).round()}%',
                        style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    const Text('مدفوع',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile(
      {required this.label,
      required this.value,
      required this.bg,
      required this.fg});

  final String label;
  final double value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
          CountUpText(
            value: value,
            format: (v) => money(v.round()),
            style: GoogleFonts.cairo(
                fontSize: 20, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs(
      {required this.index,
      required this.paymentsCount,
      required this.purchasesCount,
      required this.onChanged});

  final int index;
  final int paymentsCount;
  final int purchasesCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!;

    Widget tab(String label, int i) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(i),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: 300.ms,
                style: base.copyWith(
                  fontSize: 15,
                  fontWeight: index == i ? FontWeight.w700 : FontWeight.w600,
                  color: index == i ? AppColors.ink : const Color(0xFF475467),
                ),
                child: Text(label),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EBF0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = (constraints.maxWidth - 4) / 2;
            return Stack(
              children: [
                AnimatedPositionedDirectional(
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                  start: index == 0 ? 0 : w + 4,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    tab('الدفعات · $paymentsCount', 0),
                    const SizedBox(width: 4),
                    tab('المشتريات · $purchasesCount', 1),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.number});

  final Payment payment;
  final int number;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF0F4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: AppColors.tealDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p.note ?? '').isNotEmpty ? p.note! : 'دفعة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'الدفعة $number · ${arDate(p.paidAt)} · ${p.method.label}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '+${money(p.amount)}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.tealDark),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: AnimatedSwitcher(
              duration: 250.ms,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.5), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: Text(label, key: ValueKey(label)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('تعذّر تحميل المشروع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
