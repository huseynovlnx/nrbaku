import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// NrBaku möhürü — başlıqların yanında yanıb-sönən qızıl nöqtə.
class PatronCursor extends StatefulWidget {
  final double size;
  final Color? color;
  const PatronCursor({super.key, this.size = 10, this.color});

  @override
  State<PatronCursor> createState() => _PatronCursorState();
}

class _PatronCursorState extends State<PatronCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(CurveTween(curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color ?? AppTheme.purple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (widget.color ?? AppTheme.purple).withOpacity(0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// NrBaku başlıq widget-i — Playfair şrifti ilə böyük, oxunaqlı.
class NrBakuTitle extends StatelessWidget {
  final String text;
  final double size;
  const NrBakuTitle(this.text, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: AppTheme.heading(size: size),
        ),
        const SizedBox(width: 8),
        PatronCursor(size: size * 0.38),
      ],
    );
  }
}

/// Kartel kart çərçivəsi — qızıl kənar, tünd fon.
class KartelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  const KartelCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: borderColor ?? AppTheme.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purple.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Məxfi damğa — "◆ MƏXFI" kimi kiçik etiket.
class KartelBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const KartelBadge(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: c.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '◆ $label',
        style: GoogleFonts.sourceCodePro(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
