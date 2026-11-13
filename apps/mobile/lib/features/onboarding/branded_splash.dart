import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/branding.dart';
import '../../core/theme.dart';
import '../../core/widgets/brand_mark.dart';

/// The branded opening experience shown after the native/web loader and before
/// onboarding or sign-in.
///
/// The animation is short (1.7 s) and purely decorative: it never gates
/// network work, and [onFinished] fires as soon as the animation ends. When the
/// platform asks for reduced motion the final frame is shown immediately and
/// the callback runs on the next frame, so it adds no delay.
class BrandedSplash extends StatefulWidget {
  const BrandedSplash({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _progress;

  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });

    _logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.62, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.38, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.62, curve: Curves.easeOut),
    );
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.82, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 1, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final logoSize =
        math.min(math.max(screen.width * 0.30, 96), 136).toDouble();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _SplashBackdropPainter(t: _controller.value),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: BrandMark(
                              size: logoSize,
                              borderColor: Colors.white.withValues(alpha: 0.24),
                              elevated: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeTransition(
                          opacity: _textFade,
                          child: Column(
                            children: [
                              Text(
                                AppBranding.officeName.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SlideTransition(
                                position: _nameSlide,
                                child: const Text(
                                  AppBranding.appName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              FadeTransition(
                                opacity: _taglineFade,
                                child: const SizedBox(
                                  width: 300,
                                  child: Text(
                                    AppBranding.tagline,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => SizedBox(
                          width: 132,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 2.5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.16),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Preparing your workspace',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
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

/// Slow, low-contrast rings and a gold arc behind the seal. Drawn by hand so
/// the splash does not depend on a second animation controller.
class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxRadius = size.shortestSide * 0.58;

    final glowRect = Rect.fromCircle(center: center, radius: maxRadius * 1.45);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.075),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(glowRect);
    canvas.drawCircle(center, maxRadius * 1.45, glow);

    for (var i = 0; i < 3; i++) {
      final radius = maxRadius * (0.52 + i * 0.17) + (t * 12 * (i + 1));
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.accent.withValues(alpha: 0.10 - i * 0.022);
      canvas.drawCircle(center, radius, ring);
    }

    final arcRect = Rect.fromCircle(center: center, radius: maxRadius * 0.86);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.accent.withValues(alpha: 0.34),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(arcRect);
    canvas.drawArc(arcRect, t * 0.9, math.pi * 0.72, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) =>
      oldDelegate.t != t;
}
