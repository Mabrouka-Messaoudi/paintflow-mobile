import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../data/client_summary.dart';
import '../../data/clients_repository.dart';

Future<void> showAddClientSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddClientSheet(),
  );
}

class _AddClientSheet extends ConsumerStatefulWidget {
  const _AddClientSheet();

  @override
  ConsumerState<_AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<_AddClientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _amount = TextEditingController();
  ClientStatus _status = ClientStatus.todo;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? _parseAmount(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(clientsRepositoryProvider).createClient(
            fullName: _name.text.trim(),
            phone: _orNull(_phone.text),
            address: _orNull(_address.text),
            agreedAmount: _parseAmount(_amount.text)!,
            status: _status,
          );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تمت إضافة الحريف ✅'),
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
    final t = Theme.of(context).textTheme;

    Widget field(String label, Widget input) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054))),
              const SizedBox(height: 6),
              input,
            ],
          ),
        );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('حريف جديد', style: t.titleLarge),
              const SizedBox(height: 4),
              const Text('أدخل بيانات الحريف ومشروعه',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              field(
                'اسم الحريف',
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
              ),
              field(
                'رقم الهاتف (اختياري)',
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                ),
              ),
              field(
                'العنوان (اختياري)',
                TextFormField(
                  controller: _address,
                  textInputAction: TextInputAction.next,
                ),
              ),
              field(
                'المبلغ المتفق عليه (د.ت)',
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  validator: (v) {
                    final n = _parseAmount(v);
                    if (n == null) return 'أدخل مبلغاً صحيحاً';
                    if (n < 0) return 'المبلغ لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
              ),
              field(
                'الحالة',
                SegmentedButton<ClientStatus>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.tealSoft,
                    selectedForegroundColor: AppColors.tealDark,
                  ),
                  segments: [
                    for (final s in ClientStatus.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
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
              FilledButton(
                style: FilledButton.styleFrom(
                  disabledBackgroundColor:
                      AppColors.teal.withValues(alpha: 0.7),
                ),
                onPressed: _saving ? null : _save,
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
                      : const Text('حفظ الحريف', key: ValueKey('label')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
