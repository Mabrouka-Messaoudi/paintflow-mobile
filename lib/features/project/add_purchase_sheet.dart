import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../data/client_summary.dart';
import '../../data/project_repository.dart';

Future<void> showAddPurchaseSheet(BuildContext context, ClientSummary client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddPurchaseSheet(client: client),
  );
}

class _AddPurchaseSheet extends ConsumerStatefulWidget {
  const _AddPurchaseSheet({required this.client});

  final ClientSummary client;

  @override
  ConsumerState<_AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends ConsumerState<_AddPurchaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _shop = TextEditingController();
  final _picker = ImagePicker();
  double _qty = 1;
  DateTime _date = DateTime.now();
  Uint8List? _receipt;
  Uint8List? _itemPhoto;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _shop.dispose();
    super.dispose();
  }

  double? _parse(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  double get _total => _qty * (_parse(_price.text) ?? 0);

  Future<Uint8List?> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.teal),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: AppColors.teal),
              title: const Text('المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    return file?.readAsBytes();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(projectRepositoryProvider).addPurchase(
            clientId: widget.client.id,
            itemName: _name.text.trim(),
            quantity: _qty,
            unitPrice: _parse(_price.text)!,
            shopName: _shop.text.trim().isEmpty ? null : _shop.text.trim(),
            purchasedAt: _date,
            receiptBytes: _receipt,
            itemPhotoBytes: _itemPhoto,
          );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تمت إضافة الشراء ✅'),
      ));
    } on StorageException catch (e) {
      setState(() => _error = 'تعذّر رفع الصورة: ${e.message}');
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
    const labelStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054));

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text, style: labelStyle),
        );

    final hasPhotos = _receipt != null || _itemPhoto != null;

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
              Text('شراء جديد', style: t.titleLarge),
              const SizedBox(height: 2),
              Text('شانطي ${widget.client.fullName}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSlot(
                      label: 'صورة الفاتورة',
                      icon: Icons.receipt_long_outlined,
                      bytes: _receipt,
                      onPick: () async {
                        final b = await _pickPhoto();
                        if (b != null) setState(() => _receipt = b);
                      },
                      onRemove: () => setState(() => _receipt = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      label: 'صورة المشتريات',
                      icon: Icons.photo_camera_outlined,
                      bytes: _itemPhoto,
                      onPick: () async {
                        final b = await _pickPhoto();
                        if (b != null) setState(() => _itemPhoto = b);
                      },
                      onRemove: () => setState(() => _itemPhoto = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              label('اسم المادة'),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(hintText: 'مثال: دهن أبيض مات 18 ل'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'اسم المادة مطلوب' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        label('الكمية'),
                        _QtyStepper(
                          value: _qty,
                          onChanged: (v) => setState(() => _qty = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        label('سعر الوحدة (د.ت)'),
                        TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textDirection: TextDirection.ltr,
                          validator: (v) {
                            final n = _parse(v);
                            if (n == null) return 'أدخل سعراً صحيحاً';
                            if (n < 0) return 'السعر لا يكون سالباً';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              label('المحل (اختياري)'),
              TextFormField(
                controller: _shop,
                decoration:
                    const InputDecoration(hintText: 'مثال: دار الدهن، صفاقس'),
              ),
              const SizedBox(height: 14),
              label('تاريخ الشراء'),
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
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.22),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('المجموع',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFFC9D2DF))),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _total),
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(
                        money(double.parse(v.toStringAsFixed(3))),
                        style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
                  disabledBackgroundColor:
                      AppColors.teal.withValues(alpha: 0.7),
                  disabledForegroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
                child: AnimatedSwitcher(
                  duration: 250.ms,
                  child: _saving
                      ? Row(
                          key: const ValueKey('saving'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(hasPhotos ? 'جاري رفع الصور…' : 'جاري الحفظ…'),
                          ],
                        )
                      : const Text('حفظ الشراء', key: ValueKey('label')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.icon,
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
  final Uint8List? bytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: 350.ms,
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
      ),
      child: bytes == null ? _empty() : _filled(),
    );
  }

  Widget _empty() {
    return Material(
      key: const ValueKey('empty'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: AppColors.teal.withValues(alpha: 0.35), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPick,
        child: SizedBox(
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.tealDark),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Text('اضغط للإضافة',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filled() {
    return ClipRRect(
      key: ValueKey(bytes.hashCode),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 140,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes!, fit: BoxFit.cover),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'حذف الصورة',
                onPressed: onRemove,
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45)),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onPick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('تغيير · $label',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF2F4F7),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 20, color: AppColors.ink),
        );

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          btn(Icons.add_rounded, 'زيادة الكمية', () => onChanged(value + 1)),
          Expanded(
            child: AnimatedSwitcher(
              duration: 200.ms,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                qty(value),
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          btn(Icons.remove_rounded, 'إنقاص الكمية',
              value > 1 ? () => onChanged(value - 1) : null),
        ],
      ),
    );
  }
}
