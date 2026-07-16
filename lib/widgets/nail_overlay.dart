import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The nail-tip styles a customer can pick, matching what a technician offers.
enum NailShape { square, round, almond, coffin, stiletto }

extension NailShapeLabel on NailShape {
  String get label {
    switch (this) {
      case NailShape.square:
        return 'Square';
      case NailShape.round:
        return 'Round';
      case NailShape.almond:
        return 'Almond';
      case NailShape.coffin:
        return 'Coffin';
      case NailShape.stiletto:
        return 'Stiletto';
    }
  }
}

/// Builds the silhouette of a natural nail inside a [size] box for the chosen
/// [shape].
///
/// Every shape keeps a rounded cuticle across the BOTTOM edge and grows towards
/// the free-edge (tip) at the TOP; only the sides and tip differ. Keeping the
/// cuticle at the bottom lets callers anchor scaling/rotation there, exactly as
/// a real nail grows from its base.
Path nailSilhouette(Size s, [NailShape shape = NailShape.almond]) {
  final w = s.width, h = s.height;
  final p = Path();
  // Cuticle (bottom) - a soft curve shared by every shape.
  p.moveTo(w * 0.18, h * 0.88);
  p.quadraticBezierTo(w * 0.50, h * 1.02, w * 0.82, h * 0.88);
  switch (shape) {
    case NailShape.square:
      // Near-parallel sides, flat free-edge with softly rounded corners.
      p.cubicTo(w * 0.88, h * 0.62, w * 0.90, h * 0.40, w * 0.90, h * 0.20);
      p.cubicTo(w * 0.90, h * 0.07, w * 0.81, h * 0.04, w * 0.70, h * 0.04);
      p.lineTo(w * 0.30, h * 0.04);
      p.cubicTo(w * 0.19, h * 0.04, w * 0.10, h * 0.07, w * 0.10, h * 0.20);
      p.cubicTo(w * 0.10, h * 0.40, w * 0.12, h * 0.62, w * 0.18, h * 0.88);
      break;
    case NailShape.round:
      // Gently tapered sides curving into a semicircular tip.
      p.cubicTo(w * 0.90, h * 0.64, w * 0.92, h * 0.42, w * 0.86, h * 0.24);
      p.cubicTo(w * 0.80, h * 0.04, w * 0.20, h * 0.04, w * 0.14, h * 0.24);
      p.cubicTo(w * 0.08, h * 0.42, w * 0.10, h * 0.64, w * 0.18, h * 0.88);
      break;
    case NailShape.almond:
      // Belly out at the sides, then taper to a soft point at the tip so it
      // reads as an almond rather than a plain oval.
      p.cubicTo(w * 0.94, h * 0.68, w * 0.88, h * 0.40, w * 0.66, h * 0.14);
      p.quadraticBezierTo(w * 0.54, 0, w * 0.50, 0);
      p.quadraticBezierTo(w * 0.46, 0, w * 0.34, h * 0.14);
      p.cubicTo(w * 0.12, h * 0.40, w * 0.06, h * 0.68, w * 0.18, h * 0.88);
      break;
    case NailShape.coffin:
      // Sides taper inwards to a flat, narrow "ballerina" tip.
      p.cubicTo(w * 0.92, h * 0.66, w * 0.85, h * 0.38, w * 0.74, h * 0.12);
      p.lineTo(w * 0.67, h * 0.05);
      p.lineTo(w * 0.33, h * 0.05);
      p.lineTo(w * 0.26, h * 0.12);
      p.cubicTo(w * 0.15, h * 0.38, w * 0.08, h * 0.66, w * 0.18, h * 0.88);
      break;
    case NailShape.stiletto:
      // Sides taper all the way to a sharp point at the tip.
      p.cubicTo(w * 0.92, h * 0.64, w * 0.80, h * 0.34, w * 0.50, h * 0.02);
      p.cubicTo(w * 0.20, h * 0.34, w * 0.08, h * 0.64, w * 0.18, h * 0.88);
      break;
  }
  p.close();
  return p;
}

class _NailClipper extends CustomClipper<Path> {
  final NailShape shape;
  const _NailClipper(this.shape);

  @override
  Path getClip(Size size) => nailSilhouette(size, shape);

  @override
  bool shouldReclip(covariant _NailClipper oldClipper) =>
      oldClipper.shape != shape;
}

/// Paints a soft contact shadow beneath the nail so it grounds onto the skin
/// instead of floating like a sticker.
class _ContactShadowPainter extends CustomPainter {
  final NailShape shape;
  const _ContactShadowPainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape).shift(const Offset(0, 1.5));
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ContactShadowPainter oldDelegate) =>
      oldDelegate.shape != shape;
}

/// Paints the finishing touches on top of the design: a glossy highlight near
/// the tip, a subtle darkened cuticle for depth, and a feathered rim so the
/// edge blends into the surrounding skin rather than ending in a hard line.
class _NailFinishPainter extends CustomPainter {
  final NailShape shape;
  const _NailFinishPainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape);
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(path);

    // Convex curvature: darken the left and right edges so the nail reads as
    // rounded (light bends off the sides) rather than a flat cut-out.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          [
            Colors.black.withValues(alpha: 0.17),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.17),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Soft overall sheen towards the tip.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.42, size.height * 0.30),
          size.width * 0.62,
          [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Bright specular streak down the length for a glossy, curved highlight.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.32, 0),
          Offset(size.width * 0.52, 0),
          [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Soft shading at the cuticle for a rounded, 3D base.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.70),
          Offset(0, size.height),
          [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.18),
          ],
        ),
    );
    canvas.restore();

    // Feathered rim: a blurred translucent stroke hugging the silhouette so the
    // edge dissolves into the skin instead of a crisp cut-out line.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
  }

  @override
  bool shouldRepaint(covariant _NailFinishPainter oldDelegate) =>
      oldDelegate.shape != shape;
}

/// A single nail: the chosen design rendered INSIDE a natural nail-shaped
/// template (mask), with a contact shadow, gloss and feathered edges so it
/// reads as a real nail rather than a flat PNG pasted on the photo.
///
/// The widget fills its parent box; the caller sizes/positions/rotates it and
/// picks the [shape] of the free-edge.
class NailOverlay extends StatelessWidget {
  final String asset;
  final double opacity;
  final NailShape shape;
  const NailOverlay({
    super.key,
    required this.asset,
    this.opacity = 0.92,
    this.shape = NailShape.almond,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ContactShadowPainter(shape)),
        Opacity(
          opacity: opacity,
          child: ClipPath(
            clipper: _NailClipper(shape),
            // BoxFit.cover so the design fills the whole nail silhouette; the
            // artwork is scaled, never stretched out of proportion.
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
        CustomPaint(painter: _NailFinishPainter(shape)),
      ],
    );
  }
}

/// A small solid-colour preview of a nail [shape], used in the shape picker so
/// the customer sees the actual silhouette (not an icon) before choosing.
class NailShapePreview extends StatelessWidget {
  final NailShape shape;
  final Color color;
  const NailShapePreview({
    super.key,
    required this.shape,
    this.color = const Color(0xFFDF6E8C),
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ShapeFillPainter(shape, color));
}

class _ShapeFillPainter extends CustomPainter {
  final NailShape shape;
  final Color color;
  const _ShapeFillPainter(this.shape, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape);
    canvas.drawPath(path, Paint()..color = color);
    canvas.save();
    canvas.clipPath(path);
    // A hint of gloss so the swatch reads as a glossy nail, not a flat blob.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.42, size.height * 0.30),
          size.width * 0.60,
          [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapeFillPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}
