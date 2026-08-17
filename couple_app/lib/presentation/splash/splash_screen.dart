import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Tətbiq açılışında göstərilən splash ekranı.
/// Minimum [minDuration] müddətində görünür, sonra [onFinished] çağırılır.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  final Duration minDuration;

  const SplashScreen({
    super.key,
    this.onFinished,
    this.minDuration = const Duration(milliseconds: 3400),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Loqo/ürəklərin peyda olma animasiyası
  late final AnimationController _entranceCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // İki ürəyin bir-birinə yaxınlaşıb birləşməsi
  late final AnimationController _heartsCtrl;
  late final Animation<double> _heartsGap;
  late final Animation<double> _pulseScale;

  // "Sesi" mətninin hərf-hərf peyda olması
  late final AnimationController _titleCtrl;

  // Sloqanın fade-in-i
  late final AnimationController _sloganCtrl;
  late final Animation<double> _sloganOpacity;
  late final Animation<Offset> _sloganSlide;

  // Arxa fon hissəcikləri (üzən ürəklər)
  late final AnimationController _particleCtrl;
  final List<_Particle> _particles =
      List.generate(14, (i) => _Particle(seed: i));

  // Aşağıdakı dolan progress xətti
  late final AnimationController _progressCtrl;

  static const String _title = 'NrBaku';

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _heartsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true, period: const Duration(milliseconds: 1600));
    _heartsGap = Tween<double>(begin: 26, end: 6).animate(
      CurvedAnimation(parent: _heartsCtrl, curve: Curves.easeInOut),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _heartsCtrl, curve: Curves.easeInOut),
    );

    _titleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 90 * _title.length),
    );

    _sloganCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sloganOpacity = CurvedAnimation(parent: _sloganCtrl, curve: Curves.easeOut);
    _sloganSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sloganCtrl, curve: Curves.easeOut));

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.minDuration,
    )..forward();

    _runSequence();
  }

  Future<void> _runSequence() async {
    final stopwatch = Stopwatch()..start();

    await _entranceCtrl.forward();
    await _titleCtrl.forward();
    await _sloganCtrl.forward();

    final elapsed = stopwatch.elapsed;
    final remaining = widget.minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _heartsCtrl.dispose();
    _titleCtrl.dispose();
    _sloganCtrl.dispose();
    _particleCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arxa fon gradienti
          Container(decoration: const BoxDecoration(gradient: AppTheme.gradient)),

          // Üzən ürək hissəcikləri
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleCtrl.value,
              ),
            ),
          ),

          // Mərkəzi məzmun
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // NrBaku loqosu — qalxan + yanıb-sönən nöqtə
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: AnimatedBuilder(
                      animation: _heartsCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // "NrBaku" başlığı — hərf-hərf peyda olur
                AnimatedBuilder(
                  animation: _titleCtrl,
                  builder: (_, __) {
                    final visibleCount =
                        (_titleCtrl.value * _title.length).ceil();
                    return RichText(
                      text: TextSpan(
                        children: List.generate(_title.length, (i) {
                          final isVisible = i < visibleCount;
                          return TextSpan(
                            text: _title[i],
                            style: AppTheme.heading(
                              size: 44,
                              color: Colors.white
                                  .withValues(alpha: isVisible ? 1.0 : 0.0),
                              spacing: 3,
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Sloqan
                SlideTransition(
                  position: _sloganSlide,
                  child: FadeTransition(
                    opacity: _sloganOpacity,
                    child: Text(
                      'Uzaqda olsan belə, yaxınsan 💫',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 4),

                // Dolan progress xətti
                FadeTransition(
                  opacity: _sloganOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: _FillingBar(controller: _progressCtrl),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Versiya nömrəsi
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _sloganOpacity,
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hissəcik modeli ──────────────────────────────────────────────────────
class _Particle {
  final double x;       // 0..1 üfüqi mövqe
  final double baseY;   // 0..1 başlanğıc şaquli mövqe
  final double size;
  final double speed;   // sürət əmsalı
  final double phase;   // fərdi faza sürüşməsi
  final double opacity;

  _Particle({required int seed})
      : x = _rand(seed, 1),
        baseY = _rand(seed, 2),
        size = 8 + _rand(seed, 3) * 14,
        speed = 0.4 + _rand(seed, 4) * 0.6,
        phase = _rand(seed, 5) * 2 * pi,
        opacity = 0.08 + _rand(seed, 6) * 0.14;

  static double _rand(int seed, int salt) {
    final r = Random(seed * 7919 + salt * 104729);
    return r.nextDouble();
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1, dövrü təkrarlanır

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Yuxarı doğru üzən, yüngül üfüqi yellənən hərəkət
      final t = (progress * p.speed + p.phase / (2 * pi)) % 1.0;
      final y = size.height * (p.baseY - t) % size.height;
      final normalizedY = y < 0 ? y + size.height : y;
      final wobble = sin((progress * 2 * pi * p.speed) + p.phase) * 10;
      final dx = size.width * p.x + wobble;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity * 0.6)
        ..style = PaintingStyle.fill;

      // Ürək əvəzinə kiçik almaz/nöqtə — NrBaku kartel estetikası
      _drawDiamond(canvas, Offset(dx, normalizedY), p.size * 0.7, paint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final s = size / 2;
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.6, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s * 0.6, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── Aşağıda dolan progress xətti ─────────────────────────────────────────
class _FillingBar extends StatelessWidget {
  final AnimationController controller;
  const _FillingBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Boş track
                Container(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                // Dolan hissə
                FractionallySizedBox(
                  widthFactor: controller.value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC9A84C), Color(0xFFE8C96A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
