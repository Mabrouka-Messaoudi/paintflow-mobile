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
import '../../data/finance_repository.dart';
import '../../data/payment.dart';
import '../../data/purchase.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(clientsProvider);
    ref.invalidate(allPaymentsProvider);
    ref.invalidate(allPurchasesProvider);
    ref.invalidate(expensesProvider);
    ref.invalidate(wagesProvider);
  }

  Future<void> _add({required bool wage}) async {
    final data = await showModalBottomSheet<_EntryData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _EntrySheet(
        title: wage ? 'تسجيل أجر عامل' : 'تسجيل مصروف',
        nameLabel: wage ? 'اسم العامل' : 'عنوان المصروف',
      ),
    );
    if (data == null || !mounted) return;

    final repo = ref.read(financeRepositoryProvider);
    try {
      if (wage) {
        await repo.addWage(
            workerName: data.name,
            amount: data.amount,
            date: data.date,
            note: data.note);
        ref.invalidate(wagesProvider);
      } else {
        await repo.addExpense(
            title: data.name,
            amount: data.amount,
            date: data.date,
            note: data.note);
        ref.invalidate(expensesProvider);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر الحفظ، حاول مرة أخرى')),
      );
    }
  }

  Future<bool> _confirmDelete(String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف «$what»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.orange))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).value ?? const <ClientSummary>[];
    final names = {for (final c in clients) c.id: c.fullName};

    final payments = ref.watch(allPaymentsProvider);
    final purchases = ref.watch(allPurchasesProvider);
    final expenses = ref.watch(expensesProvider);
    final wages = ref.watch(wagesProvider);

    final showFab = _tabs.index >= 3;

    return Scaffold(
      body: Column(
        children: [
          NavyHeader(
            child: Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'رجوع',
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مكتبك',
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14, color: const Color(0xFFA9B4C6))),
                      Text('المقبوضات',
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(top: 12),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.teal,
              dividerColor: AppColors.border,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'نظرة عامة'),
                Tab(text: 'المقبوضات'),
                Tab(text: 'السلع'),
                Tab(text: 'المصاريف'),
                Tab(text: 'أجور العمال'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  clients: clients,
                  expenses: expenses.value ?? const <Expense>[],
                  wages: wages.value ?? const <Wage>[],
                  onRefresh: () async => _refreshAll(),
                ),
                _AsyncList<Payment>(
                  value: payments,
                  onRefresh: () => ref.refresh(allPaymentsProvider.future),
                  totalLabel: 'إجمالي المقبوضات',
                  totalOf: (l) => l.fold<double>(0, (s, p) => s + p.amount),
                  emptyText: 'لا توجد مقبوضات بعد',
                  itemBuilder: (p) => _EntryCard(
                    icon: Icons.payments_outlined,
                    color: AppColors.tealDark,
                    title: names[p.clientId] ?? 'حريف محذوف',
                    subtitle:
                        '${p.method.label} · ${arDate(p.paidAt)}${(p.note ?? '').isEmpty ? '' : ' · ${p.note}'}',
                    amount: p.amount,
                  ),
                ),
                _AsyncList<Purchase>(
                  value: purchases,
                  onRefresh: () => ref.refresh(allPurchasesProvider.future),
                  totalLabel: 'إجمالي السلع',
                  totalOf: (l) => l.fold<double>(0, (s, p) => s + p.total),
                  emptyText: 'لا توجد سلع مسجّلة بعد',
                  itemBuilder: (p) => _EntryCard(
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.orange,
                    title: p.itemName,
                    subtitle:
                        '${names[p.clientId] ?? 'حريف محذوف'} · ${qty(p.quantity)} × ${money(p.unitPrice)}'
                        '${(p.shopName ?? '').isEmpty ? '' : ' · ${p.shopName}'} · ${arDate(p.purchasedAt)}',
                    amount: p.total,
                  ),
                ),
                _AsyncList<Expense>(
                  value: expenses,
                  onRefresh: () => ref.refresh(expensesProvider.future),
                  totalLabel: 'إجمالي المصاريف',
                  totalOf: (l) => l.fold<double>(0, (s, e) => s + e.amount),
                  emptyText: 'لا توجد مصاريف بعد',
                  itemBuilder: (e) => _EntryCard(
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.orange,
                    title: e.title,
                    subtitle:
                        '${arDate(e.spentAt)}${(e.note ?? '').isEmpty ? '' : ' · ${e.note}'}',
                    amount: e.amount,
                    onDelete: () async {
                      if (await _confirmDelete(e.title)) {
                        await ref
                            .read(financeRepositoryProvider)
                            .deleteExpense(e.id);
                        ref.invalidate(expensesProvider);
                      }
                    },
                  ),
                ),
                _AsyncList<Wage>(
                  value: wages,
                  onRefresh: () => ref.refresh(wagesProvider.future),
                  totalLabel: 'إجمالي أجور العمال',
                  totalOf: (l) => l.fold<double>(0, (s, w) => s + w.amount),
                  emptyText: 'لا توجد أجور مسجّلة بعد',
                  itemBuilder: (w) => _EntryCard(
                    icon: Icons.engineering_outlined,
                    color: AppColors.navy,
                    title: w.workerName,
                    subtitle:
                        '${arDate(w.paidAt)}${(w.note ?? '').isEmpty ? '' : ' · ${w.note}'}',
                    amount: w.amount,
                    onDelete: () async {
                      if (await _confirmDelete(w.workerName)) {
                        await ref
                            .read(financeRepositoryProvider)
                            .deleteWage(w.id);
                        ref.invalidate(wagesProvider);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () => _add(wage: _tabs.index == 4),
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.add_rounded),
              label: Text(_tabs.index == 4 ? 'أجر جديد' : 'مصروف جديد',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.clients,
    required this.expenses,
    required this.wages,
    required this.onRefresh,
  });

  final List<ClientSummary> clients;
  final List<Expense> expenses;
  final List<Wage> wages;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final agreed = clients.fold<double>(0, (s, c) => s + c.agreedAmount);
    final received = clients.fold<double>(0, (s, c) => s + c.received);
    final remaining = clients.fold<double>(0, (s, c) => s + c.remaining);
    final goods = clients.fold<double>(0, (s, c) => s + c.purchasesTotal);
    final expensesTotal = expenses.fold<double>(0, (s, e) => s + e.amount);
    final wagesTotal = wages.fold<double>(0, (s, w) => s + w.amount);
    final spent = goods + expensesTotal + wagesTotal;
    final net = received - spent;
    final progress =
        agreed <= 0 ? 0.0 : (received / agreed).clamp(0, 1).toDouble();

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الربح الصافي',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                CountUpText(
                  value: net,
                  format: money,
                  style: GoogleFonts.cairo(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: net >= 0 ? AppColors.tealDark : AppColors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('المقبوضات − (السلع + المصاريف + أجور العمال)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
                AnimatedProgressBar(value: progress),
                const SizedBox(height: 8),
                Text(
                  'تم قبض ${money(received)} من ${money(agreed)} المتفق عليه',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
          const SizedBox(height: 12),
          Row(children: [
            _StatTile(
                icon: Icons.south_west_rounded,
                label: 'المقبوضات',
                value: received,
                color: AppColors.tealDark),
            const SizedBox(width: 12),
            _StatTile(
                icon: Icons.hourglass_bottom_rounded,
                label: 'المتبقي',
                value: remaining,
                color: AppColors.orange),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatTile(
                icon: Icons.shopping_bag_outlined,
                label: 'السلع',
                value: goods,
                color: AppColors.ink),
            const SizedBox(width: 12),
            _StatTile(
                icon: Icons.receipt_long_outlined,
                label: 'المصاريف',
                value: expensesTotal,
                color: AppColors.ink),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatTile(
                icon: Icons.engineering_outlined,
                label: 'أجور العمال',
                value: wagesTotal,
                color: AppColors.ink),
            const SizedBox(width: 12),
            _StatTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'مجموع المصروفات',
                value: spent,
                color: AppColors.orange),
          ]),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
              ),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(money(value),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }
}

// ---------------------------------------------------------------------------
// Generic list tab
// ---------------------------------------------------------------------------

class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.value,
    required this.onRefresh,
    required this.itemBuilder,
    required this.totalOf,
    required this.totalLabel,
    required this.emptyText,
  });

  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget Function(T item) itemBuilder;
  final double Function(List<T> list) totalOf;
  final String totalLabel;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.teal)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 52, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل البيانات',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
      data: (list) => RefreshIndicator(
        color: AppColors.teal,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(totalLabel,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text(money(totalOf(list)),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(emptyText,
                      style: const TextStyle(color: AppColors.muted)),
                ),
              ),
            for (final item in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: itemBuilder(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.onDelete,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(money(amount),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          if (onDelete != null)
            IconButton(
              tooltip: 'حذف',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add sheet (expense / wage)
// ---------------------------------------------------------------------------

class _EntryData {
  const _EntryData(this.name, this.amount, this.note, this.date);

  final String name;
  final double amount;
  final String? note;
  final DateTime date;
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.title, required this.nameLabel});

  final String title;
  final String nameLabel;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _submit() {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'أدخل الاسم ومبلغاً صحيحاً');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
        context, _EntryData(name, amount, note.isEmpty ? null : note, _date));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title,
                style: GoogleFonts.cairo(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: widget.nameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ (د.ت)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(arDate(_date)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.orange)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}
