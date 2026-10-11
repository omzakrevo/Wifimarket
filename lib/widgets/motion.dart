import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';

/// Rebond tactile : le widget se « tasse » légèrement sous le doigt.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.borderRadius});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.quick,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Entrée en cascade : fondu + glissement vers le haut, décalé selon l'index.
extension RevealX on Widget {
  Widget reveal({int index = 0, Duration? delay, double dy = 0.08}) => animate(delay: delay ?? Motion.stagger(index))
      .fadeIn(duration: Motion.base, curve: Motion.enter)
      .slideY(begin: dy, end: 0, duration: Motion.slow, curve: Motion.emphasized);

  Widget popIn({int index = 0}) => animate(delay: Motion.stagger(index))
      .fadeIn(duration: Motion.quick)
      .scale(begin: const Offset(.92, .92), end: const Offset(1, 1), duration: Motion.base, curve: Curves.easeOutBack);
}

/// Squelette de chargement avec reflet animé.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.radius = 12});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(radius)),
    ).animate(onPlay: (ctl) => ctl.repeat()).shimmer(
          duration: 1400.ms,
          color: c.surface.withValues(alpha: .55),
        );
  }
}

/// Compteur qui monte jusqu'à sa valeur.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, this.style, this.format});
  final num value;
  final TextStyle? style;
  final String Function(num)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.slow * 1.6,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format != null ? format!(v) : v.round().toString(), style: style),
    );
  }
}

/// Bouton plein dégradé « Signal », avec effet de pression.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient = WM.signalGradient,
    this.foreground = Colors.white,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Gradient gradient;
  final Color foreground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = AnimatedSwitcher(
      duration: Motion.quick,
      child: loading
          ? SizedBox(
              key: const ValueKey('l'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: foreground),
            )
          : Row(
              key: const ValueKey('t'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 20, color: foreground), const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground, fontSize: 15)),
                ),
              ],
            ),
    );
    final btn = Opacity(
      opacity: enabled || loading ? 1 : .5,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: WM.wave.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: content,
      ),
    );
    return Pressable(onTap: enabled ? onPressed : null, child: expand ? SizedBox(width: double.infinity, child: btn) : btn);
  }
}

/// Logo WiFiMarket dessiné en code (aucun fichier image nécessaire).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter()));
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * .3));
    canvas.drawRRect(r, Paint()..shader = WM.signalGradient.createShader(Offset.zero & s));
    final center = Offset(s.width / 2, s.height * .72);
    final stroke = s.width * .085;
    for (var i = 0; i < 3; i++) {
      final radius = s.width * (.16 + i * .17);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = i == 0 ? WM.volt : Colors.white;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi * .86, math.pi * .72, false, p);
    }
    canvas.drawCircle(center, stroke * .95, Paint()..color = WM.volt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class LogoWordmark extends StatelessWidget {
  const LogoWordmark({super.key, this.light = false, this.size = 34});
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
          color: light ? Colors.white : Theme.of(context).colorScheme.onSurface,
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LogoMark(size: size),
      const SizedBox(width: 10),
      Text.rich(TextSpan(children: [
        TextSpan(text: 'WiFi', style: style),
        TextSpan(text: 'Market', style: style?.copyWith(color: light ? WM.signal : Theme.of(context).colorScheme.primary)),
      ])),
    ]);
  }
}

/// Anneaux de signal qui se propagent depuis un point : l'élément visuel signature du site.
class WifiRings extends StatefulWidget {
  const WifiRings({super.key, this.color = WM.signal, this.rings = 4, this.alignment = Alignment.bottomRight});
  final Color color;
  final int rings;
  final Alignment alignment;

  @override
  State<WifiRings> createState() => _WifiRingsState();
}

class _WifiRingsState extends State<WifiRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _RingsPainter(_c.value, widget.color, widget.rings, widget.alignment),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color, this.rings, this.alignment);
  final double t;
  final Color color;
  final int rings;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = alignment.alongSize(size);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height) * .9;
    for (var i = 0; i < rings; i++) {
      final p = (t + i / rings) % 1.0;
      final r = maxR * Curves.easeOutQuad.transform(p);
      final a = (1 - p) * .38;
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + (1 - p) * 2
          ..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t != t || old.color != color;
}

/// Cœur « favori » avec explosion de particules.
class HeartButton extends StatefulWidget {
  const HeartButton({super.key, required this.active, required this.onTap, this.size = 22, this.backdrop = true});
  final bool active;
  final VoidCallback onTap;
  final double size;
  final bool backdrop;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.active) _c.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pad = widget.size * .5;
    return Pressable(
      onTap: _tap,
      scale: .85,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: widget.backdrop
            ? BoxDecoration(color: scheme.surface.withValues(alpha: .86), shape: BoxShape.circle)
            : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final burst = Curves.easeOut.transform(_c.value);
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                if (_c.isAnimating)
                  for (var i = 0; i < 6; i++)
                    Transform.translate(
                      offset: Offset.fromDirection(i * math.pi / 3, burst * widget.size * .95),
                      child: Opacity(
                        opacity: (1 - burst).clamp(0, 1),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(color: WM.coral, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                AnimatedSwitcher(
                  duration: Motion.base,
                  transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
                  child: Icon(
                    widget.active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(widget.active),
                    size: widget.size,
                    color: widget.active ? WM.coral : scheme.onSurface,
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Défilement avec effet de parallaxe doux sur un fond (utilisé dans le hero).
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({super.key, required this.controller, required this.factor, required this.child});
  final ScrollController controller;
  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, c) {
        final off = controller.hasClients ? controller.offset : 0.0;
        return Transform.translate(offset: Offset(0, -off * factor), child: c);
      },
      child: child,
    );
  }
}
