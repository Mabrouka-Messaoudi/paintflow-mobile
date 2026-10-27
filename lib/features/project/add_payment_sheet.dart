import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../../data/client_summary.dart';
import '../../data/payment.dart';
import '../../data/project_repository.dart';

Future<void> showAddPaymentSheet(BuildContext context, ClientSummary client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddPaymentSheet(client: client),
  );
}

class _AddPaymentSheet extends ConsumerStatefulWidget {
  const _AddPaymentSheet({required this.client});

  final ClientSummary client;

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  void _addQuick(int v) {
    final n = _value + v;
    _amount.text =
        n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(projectRepositoryProvider).addPayment(
            clientId: widget.client.id,
            amount: _value,
            method: _method,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            paidAt: _date,
          );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تمت إضافة الدفعة ✅'),
      ));
    } on PostgrestException catch (e) {
      setState(() => _error = 'تعذّر الحفظ: ${e.message}');
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال، تحقّق من الإنترنت');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final t = Theme.of(context).textTheme;
    final newReceived = c.received + _value;
    final newRemaining = c.agreedAmount - newReceived;
    final newProgress = c.agreedAmount <= 0
        ? 0.0
        : (newReceived / c.agreedAmount).clamp(0, 1).toDouble();
    final over = _value > 0 && _value > c.remaining;

    const labelStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054));

    OutlineInputBorder border(double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.teal, width: width),
        );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('دفعة جديدة', style: t.titleLarge),
            const SizedBox(height: 2),
            Text('للحريف ${c.fullName}',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            const Text('المبلغ المستلم', style: labelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(
                  fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'د.ت',
                suffixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted),
                fillColor: const Color(0xFFF6FBFA),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                enabledBorder: border(2),
                focusedBorder: border(2.5),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final v in [500, 1000, 2000]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _addQuick(v),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('+${money(v).replaceAll(' د.ت', '')}'),
                    ),
                  ),
                  if (v != 2000) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreviewRow(
                      label: 'المستلم بعد الدفعة',
                      value: money(newReceived),
                      color: AppColors.tealDark),
                  const SizedBox(height: 8),
                  _PreviewRow(
                      label: 'المتبقي بعد الدفعة',
                      value: money(newRemaining),
                      color: AppColors.orange),
                  const SizedBox(height: 10),
                  AnimatedProgressBar(value: newProgress),
                  AnimatedSize(
                    duration: 250.ms,
                    curve: Curves.easeOutCubic,
                    child: over
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'المبلغ أكبر من المتبقي (${money(c.remaining)})',
                              style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  fontWeight: FontWeight.w600),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('التاريخ', style: labelStyle),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(arDate(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                alignment: AlignmentDirectional.centerStart,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('طريقة الدفع', style: labelStyle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final m in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                    selectedColor: AppColors.tealSoft,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _method == m
                          ? AppColors.tealDark
                          : const Color(0xFF344054),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('ملاحظة (اختياري)', style: labelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  hintText: 'مثال: بعد الطبقة الثانية'),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w600)),
              ).animate().shakeX(hz: 4, amount: 4),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
              ),
              onPressed: (_saving || _value <= 0) ? null : _save,
              child: AnimatedSwitcher(
                duration: 250.ms,
                child: _saving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('حفظ الدفعة', key: ValueKey('label')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
