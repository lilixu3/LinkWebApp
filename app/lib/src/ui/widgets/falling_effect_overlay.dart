import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';

class FallingEffectOverlay extends StatefulWidget {
  final double width;
  final double height;
  final EffectType type;
  final bool dark;

  const FallingEffectOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.type,
    required this.dark,
  });

  @override
  State<FallingEffectOverlay> createState() => _FallingEffectOverlayState();
}

class _FallingEffectOverlayState extends State<FallingEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  late final math.Random _rand;
  late List<_Particle> _particles;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _rand = math.Random();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onFrame);
    _reseed();
    _tick.repeat();
  }

  @override
  void didUpdateWidget(covariant FallingEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type ||
        (oldWidget.width - widget.width).abs() > 8 ||
        (oldWidget.height - widget.height).abs() > 8) {
      _reseed();
    }
  }

  void _reseed() {
    final area = widget.width * widget.height;
    _count = (area / 18000).clamp(18, 90).toInt();
    _particles = List.generate(_count, (_) => _Particle.random(_rand, widget));
    setState(() {});
  }

  void _onFrame() {
    for (final p in _particles) {
      p.update(widget, _rand);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == EffectType.none) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _ParticlePainter(
          particles: _particles,
          type: widget.type,
          dark: widget.dark,
        ),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double drift;
  double rotation;
  double spin;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.spin,
  });

  static _Particle random(math.Random r, FallingEffectOverlay w) {
    final baseSize = w.type == EffectType.snow ? 3.0 : 6.0;
    final s = baseSize + r.nextDouble() * baseSize;
    final sp = (w.type == EffectType.snow ? 30.0 : 55.0) + r.nextDouble() * 80.0;
    final d = (r.nextDouble() - 0.5) * (w.type == EffectType.snow ? 18.0 : 28.0);
    return _Particle(
      x: r.nextDouble() * w.width,
      y: r.nextDouble() * w.height,
      size: s,
      speed: sp,
      drift: d,
      rotation: r.nextDouble() * math.pi * 2,
      spin: (r.nextDouble() - 0.5) * (w.type == EffectType.snow ? 0.8 : 1.6),
    );
  }

  void update(FallingEffectOverlay w, math.Random r) {
    final dt = 1 / 60.0;
    y += speed * dt;
    x += drift * dt;
    rotation += spin * dt;

    if (y > w.height + 24) {
      y = -24 - r.nextDouble() * w.height * 0.2;
      x = r.nextDouble() * w.width;
    }
    if (x < -24) x = w.width + 24;
    if (x > w.width + 24) x = -24;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final EffectType type;
  final bool dark;

  _ParticlePainter({
    required this.particles,
    required this.type,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (type == EffectType.none) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (type == EffectType.snow) {
        paint.color = Colors.white.withOpacity(0.75);
        canvas.drawCircle(Offset.zero, p.size, paint);
      } else if (type == EffectType.sakura) {
        final s = p.size;
        paint.color = (dark ? const Color(0xFFFFC1D9) : const Color(0xFFFF8FBF))
            .withOpacity(0.75);
        final path = Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(s * 0.85, -s * 0.25, 0, s)
          ..quadraticBezierTo(-s * 0.85, -s * 0.25, 0, -s)
          ..close();
        canvas.drawPath(path, paint);

        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withOpacity(0.25);
        canvas.drawLine(Offset(0, -s * 0.7), Offset(0, s * 0.7), stroke);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
