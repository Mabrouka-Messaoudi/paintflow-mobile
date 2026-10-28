import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: AuthService.savedEmail);
  final _password = TextEditingController();
  bool _remember = AuthService.rememberMe;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool _bioAvailable = false; // phone has a fingerprint set up
  String? _bioEmail; // fingerprint login already enabled for this account
  bool _useBio = true; // "enable fingerprint" checkbox

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final available = await AuthService.biometricsAvailable();
    final email = available ? await AuthService.biometricEmail() : null;
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEmail = email;
    });
    // Fresh app start: ask for the fingerprint straight away.
    if (email != null && !AuthService.justSignedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bioLogin());
    }
  }

  Future<void> _bioLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithBiometrics();
      // On success the router opens the right home screen.
    } on AuthException {
      setState(() {
        _bioEmail = null;
        _error = 'تغيّرت كلمة السر. ادخل بها مرة واحدة لتفعيل البصمة من جديد';
      });
    } catch (e) {
      // Cancelling the fingerprint prompt is not an error.
      if (!e.toString().toLowerCase().contains('cancel')) {
        setState(() => _error = 'تعذّر الدخول بالبصمة، استعمل كلمة السر');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgetBio() async {
    await AuthService.disableBiometrics();
    setState(() => _bioEmail = null);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signIn(
        _email.text.trim(),
        _password.text,
        remember: _remember,
        enableBiometrics: _bioAvailable && _bioEmail == null && _useBio,
      );
      // The router redirects to the right home screen automatically.
    } on AuthException catch (e) {
      setState(() => _error = _translate(e.message));
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال، تحقّق من الإنترنت');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translate(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة السر غير صحيحة';
    }
    if (message.contains('Email not confirmed')) {
      return 'الحساب غير مفعّل بعد';
    }
    return 'حدث خطأ: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Expanded(child: _Hero()),
                  _buildForm(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style: t.labelLarge?.copyWith(
                  color: const Color(0xFF344054),
                  fontWeight: FontWeight.w600)),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          22, 28, 22, 28 + MediaQuery.paddingOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تسجيل الدخول', style: t.titleLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text('أدخل بريدك الإلكتروني وكلمة السر',
                style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            if (_bioEmail != null) ...[
              _BioButton(
                email: _bioEmail!,
                loading: _loading,
                onTap: _bioLogin,
                onForget: _forgetBio,
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('أو بكلمة السر',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
            ],
            label('البريد الإلكتروني'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'name@example.com'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'أدخل بريداً إلكترونياً صحيحاً'
                  : null,
            ),
            const SizedBox(height: 14),
            label('كلمة السر'),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'إظهار كلمة السر' : 'إخفاء كلمة السر',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'كلمة السر قصيرة جداً' : null,
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _remember = !_remember),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        activeColor: AppColors.teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        onChanged: (v) =>
                            setState(() => _remember = v ?? true),
                      ),
                      const Text('تذكّرني',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('(البقاء متصلاً على هذا الهاتف)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_bioAvailable && _bioEmail == null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _useBio = !_useBio),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _useBio,
                          activeColor: AppColors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          onChanged: (v) => setState(() => _useBio = v ?? true),
                        ),
                        const Text('تفعيل الدخول بالبصمة',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        const Icon(Icons.fingerprint_rounded,
                            color: AppColors.teal, size: 22),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
            AnimatedSize(
              duration: 300.ms,
              curve: Curves.easeOutCubic,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFB42318), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ).animate(key: ValueKey(_error)).shakeX(hz: 4, amount: 4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.7),
              ),
              onPressed: _loading ? null : _submit,
              child: AnimatedSwitcher(
                duration: 250.ms,
                child: _loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('دخول', key: ValueKey('label')),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'حساب الحريف يُنشئه الدهان ويرسل له بيانات الدخول',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    )
        .animate(delay: 150.ms)
        .slideY(begin: 1, end: 0, duration: 800.ms, curve: Curves.easeOutCubic);
  }
}

/// Big fingerprint button shown when fingerprint login is enabled.
class _BioButton extends StatelessWidget {
  const _BioButton({
    required this.email,
    required this.loading,
    required this.onTap,
    required this.onForget,
  });

  final String email;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.tealSoft,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: loading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: AppColors.teal, shape: BoxShape.circle),
                    child: const Icon(Icons.fingerprint_rounded,
                        color: Colors.white, size: 34),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                          begin: 1,
                          end: 1.08,
                          duration: 1100.ms,
                          curve: Curves.easeInOut),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الدخول بالبصمة',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tealDark)),
                        Text(email,
                            textDirection: TextDirection.ltr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.teal),
                    ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: loading ? null : onForget,
            child: const Text('إيقاف البصمة / حساب آخر',
                style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0);
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -40,
          left: -80,
          child: _Blob(color: AppColors.amber.withValues(alpha: 0.32), size: 240),
        ),
        Positioned(
          bottom: -60,
          right: -90,
          child: _Blob(
            color: AppColors.teal.withValues(alpha: 0.55),
            size: 260,
            delay: 1500.ms,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(Icons.format_paint_rounded,
                    size: 38, color: AppColors.navy),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                      begin: const Offset(0.6, 0.6),
                      duration: 700.ms,
                      curve: Curves.easeOutBack),
              const SizedBox(height: 14),
              Text(
                'PaintFlow',
                style: GoogleFonts.cairo(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              )
                  .animate(delay: 250.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 6),
              Text(
                'نظّم الشانطيات، وتابع كل دينار',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15, color: const Color(0xFFC9D2DF)),
              )
                  .animate(delay: 350.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, this.delay = Duration.zero});

  final Color color;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    )
        .animate(
            delay: delay, onPlay: (controller) => controller.repeat(reverse: true))
        .move(
            begin: Offset.zero,
            end: const Offset(18, -16),
            duration: 5.seconds,
            curve: Curves.easeInOut)
        .scaleXY(begin: 1, end: 1.1, duration: 5.seconds, curve: Curves.easeInOut);
  }
}
