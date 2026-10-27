import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/client_summary.dart';
import '../app_theme.dart';

/// Dark rounded header with two slowly floating glow blobs.
class NavyHeader extends StatelessWidget {
  const NavyHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: ColoredBox(
        color: AppColors.navy,
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -60,
              child: GlowBlob(
                  color: AppColors.amber.withValues(alpha: 0.35), size: 190),
            ),
            Positioned(
              bottom: -100,
              right: -70,
              child: GlowBlob(
                color: AppColors.teal.withValues(alpha: 0.55),
                size: 230,
                delay: 1500.ms,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class GlowBlob extends StatelessWidget {
  const GlowBlob(
      {super.key, required this.color, required this.size, this.delay = Duration.zero});

  final Color color;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    )
        .animate(delay: delay, onPlay: (c) => c.repeat(reverse: true))
        .move(
            begin: Offset.zero,
            end: const Offset(16, -14),
            duration: 5.seconds,
            curve: Curves.easeInOut)
        .scaleXY(begin: 1, end: 1.08, duration: 5.seconds, curve: Curves.easeInOut);
  }
}

/// Glassy square icon button used on the dark header.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton(
      {super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Shrinks slightly while pressed, like modern apps.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: 180.ms,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

const _avatarPalette = [
  (Color(0xFFE0ECFF), Color(0xFF1D4ED8)),
  (Color(0xFFFDE8D7), Color(0xFF9A3412)),
  (Color(0xFFE6F6F3), Color(0xFF0B6158)),
  (Color(0xFFF1E8FF), Color(0xFF6B21A8)),
  (Color(0xFFFEF3C7), Color(0xFF92400E)),
];

class ClientAvatar extends StatelessWidget {
  const ClientAvatar(
      {super.key, required this.id, required this.name, this.size = 46});

  final String id;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _avatarPalette[id.hashCode.abs() % _avatarPalette.length];
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: GoogleFonts.cairo(
              fontSize: size * 0.4, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ClientStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ClientStatus.progress => (const Color(0xFFFFF4E5), const Color(0xFF9A4A00)),
      ClientStatus.done => (const Color(0xFFE6F6F3), AppColors.tealDark),
      ClientStatus.todo => (const Color(0xFFEEF0F4), const Color(0xFF475467)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Number that counts up on first show and glides to new values.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Progress bar that fills smoothly and animates to new values.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: 1100.ms,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: const Color(0xFFEEF0F4),
          color: const Color(0xFF0E7A6E),
        ),
      ),
    );
  }
}
