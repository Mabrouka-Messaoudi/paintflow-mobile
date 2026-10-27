import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/client_summary.dart';
import '../../data/clients_repository.dart';

Future<void> showCreateAccountSheet(
    BuildContext context, ClientSummary client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CreateAccountSheet(client: client),
  );
}

/// Readable random password (no 0/O or 1/l/I confusion).
String _generatePassword([int length = 10]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

class _CreateAccountSheet extends ConsumerStatefulWidget {
  const _CreateAccountSheet({required this.client});

  final ClientSummary client;

  @override
  ConsumerState<_CreateAccountSheet> createState() =>
      _CreateAccountSheetState();
}

class _CreateAccountSheetState extends ConsumerState<_CreateAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.client.email ?? '');
  String _password = _generatePassword();
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(clientsRepositoryProvider).createAccount(
            clientId: widget.client.id,
            email: _email.text.trim().toLowerCase(),
            password: _password,
          );
      setState(() => _done = true);
    } on FunctionException catch (e) {
      final d = e.details;
      setState(() => _error = d is Map && d['error'] != null
          ? d['error'].toString()
          : 'تعذّر إنشاء الحساب (${e.status})');
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال، تحقّق من الإنترنت');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _message => 'مرحباً ${widget.client.fullName}،\n'
      'يمكنك متابعة حضيرتك (المبالغ، الدفعات، المشتريات والفواتير) على تطبيق PaintFlow.\n\n'
      'البريد الإلكتروني: ${_email.text.trim().toLowerCase()}\n'
      'كلمة السر: $_password';

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('تم نسخ $what'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _sendWhatsApp() async {
    var digits = (widget.client.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) digits = '216$digits'; // local Tunisian number
    final uri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(_message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: AnimatedSwitcher(
          duration: 400.ms,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: _done ? _success() : _form(),
        ),
      ),
    );
  }

  Widget _form() {
    final t = Theme.of(context).textTheme;
    const labelStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054));

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('حساب للحريف', style: t.titleLarge),
          const SizedBox(height: 2),
          Text('ليتابع ${widget.client.fullName} حضيرته من هاتفه',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          const Text('البريد الإلكتروني', style: labelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            autofocus: _email.text.isEmpty,
            decoration: const InputDecoration(hintText: 'name@example.com'),
            validator: (v) {
              final s = (v ?? '').trim();
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                  ? null
                  : 'أدخل بريداً إلكترونياً صحيحاً';
            },
          ),
          const SizedBox(height: 14),
          const Text('كلمة السر (مولّدة تلقائياً)', style: labelStyle),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: 250.ms,
                    child: Text(
                      _password,
                      key: ValueKey(_password),
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'توليد كلمة سر أخرى',
                  onPressed: () =>
                      setState(() => _password = _generatePassword()),
                  icon: const Icon(Icons.refresh_rounded),
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
                      color: Color(0xFFB42318), fontWeight: FontWeight.w600)),
            ).animate().shakeX(hz: 4, amount: 4),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.7),
              disabledForegroundColor: Colors.white,
            ),
            onPressed: _saving ? null : _create,
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
                  : const Text('إنشاء الحساب', key: ValueKey('label')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    final email = _email.text.trim().toLowerCase();

    Widget row(String label, String value) => Container(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text('$label  ',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted)),
              Expanded(
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'نسخ $label',
                onPressed: () => _copy(value, label),
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
        );

    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.tealSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                size: 40, color: AppColors.tealDark),
          )
              .animate()
              .scale(
                  begin: const Offset(0.4, 0.4),
                  duration: 600.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(),
        ),
        const SizedBox(height: 14),
        Text('تم إنشاء الحساب',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('أرسل بيانات الدخول للحريف. احتفظ بها، فكلمة السر لن تظهر مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              row('البريد', email),
              const SizedBox(height: 8),
              row('كلمة السر', _password),
            ],
          ),
        ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1, end: 0),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C4A)),
          onPressed: _sendWhatsApp,
          icon: const Icon(Icons.send_rounded),
          label: const Text('إرسال عبر واتساب'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () => _copy(_message, 'الرسالة كاملة'),
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('نسخ الرسالة كاملة'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('تم'),
        ),
      ],
    );
  }
}
