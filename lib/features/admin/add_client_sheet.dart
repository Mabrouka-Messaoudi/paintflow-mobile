import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../data/client_summary.dart';
import '../../data/clients_repository.dart';

Future<void> showAddClientSheet(BuildContext context) =>
    showClientFormSheet(context);

/// Add a new client, or edit [client] when given.
Future<void> showClientFormSheet(BuildContext context,
    {ClientSummary? client}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ClientFormSheet(client: client),
  );
}

class _ClientFormSheet extends ConsumerStatefulWidget {
  const _ClientFormSheet({this.client});

  final ClientSummary? client;

  @override
  ConsumerState<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends ConsumerState<_ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client?.fullName);
  late final _phone = TextEditingController(text: widget.client?.phone);
  late final _address = TextEditingController(text: widget.client?.address);
  late final _amount = TextEditingController(
      text: widget.client == null ? '' : qty(widget.client!.agreedAmount));
  late ClientStatus _status = widget.client?.status ?? ClientStatus.todo;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.client != null;

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
    final repo = ref.read(clientsRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateClient(
          id: widget.client!.id,
          fullName: _name.text.trim(),
          phone: _orNull(_phone.text),
          address: _orNull(_address.text),
          agreedAmount: _parseAmount(_amount.text)!,
          status: _status,
        );
      } else {
        await repo.createClient(
          fullName: _name.text.trim(),
          phone: _orNull(_phone.text),
          address: _orNull(_address.text),
          agreedAmount: _parseAmount(_amount.text)!,
          status: _status,
        );
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(_isEdit ? 'تم حفظ التعديلات ✅' : 'تمت إضافة الحريف ✅'),
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
    final received = widget.client?.received ?? 0;
    final newAgreed = _parseAmount(_amount.text);
    final belowReceived =
        _isEdit && newAgreed != null && newAgreed < received;

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
              Text(_isEdit ? 'تعديل بيانات الحريف' : 'حريف جديد',
                  style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                  _isEdit
                      ? 'التغييرات تظهر مباشرة عند الحريف'
                      : 'أدخل بيانات الحريف والشانطي',
                  style: const TextStyle(color: AppColors.muted)),
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
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = _parseAmount(v);
                    if (n == null) return 'أدخل مبلغاً صحيحاً';
                    if (n < 0) return 'المبلغ لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
              ),
              AnimatedSize(
                duration: 250.ms,
                curve: Curves.easeOutCubic,
                child: belowReceived
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'تنبيه: المبلغ أقل مما استلمته (${money(received)})، فسيصبح المتبقي سالباً.',
                          style: const TextStyle(
                              color: Color(0xFFB54708),
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
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
                      : Text(_isEdit ? 'حفظ التعديلات' : 'حفظ الحريف',
                          key: const ValueKey('label')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
