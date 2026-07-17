import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A measurement of the photo's ambient light, used to tint the painted nails so
/// they sit in the SAME light as the hand instead of glowing like a flat sticker
/// pasted on top. It is a simple per-channel scale (a diagonal colour matrix):
/// a dim photo darkens the nail, a warm room warms it, a cool room cools it.
///
/// The scales are derived on-device by averaging the photo's colour once when it
/// loads (see [_VirtualTryOnScreenState._computeAmbient]) — no AI, no cloud.
class AmbientLight {
  final double rScale, gScale, bScale;
  const AmbientLight(this.rScale, this.gScale, this.bScale);

  /// No adjustment (used before a photo's light has been measured).
  static const neutral = AmbientLight(1, 1, 1);

  bool get isNeutral => rScale == 1 && gScale == 1 && bScale == 1;

  /// A diagonal colour matrix that applies the per-channel scale.
  ColorFilter get filter => ColorFilter.matrix(<double>[
        rScale, 0, 0, 0, 0,
        0, gScale, 0, 0, 0,
        0, 0, bScale, 0, 0,
        0, 0, 0, 1, 0,
      ]);
}

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
    final base = nailSilhouette(size, shape);
    // Two-layer grounding: a broad, soft ambient-occlusion pool that spreads
    // onto the skin, plus a tighter, darker contact line right under the edge.
    // Together they stop the nail reading as a flat cut-out floating on the
    // photo and instead sit it into the finger.
    canvas.drawPath(
      base.shift(const Offset(0.4, 2.6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
    );
    canvas.drawPath(
      base.shift(const Offset(0.2, 1.0)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
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

    // Tight specular hotspot: the small, bright pinpoint where the light source
    // reflects off the glossy curve. This single hotspot is the strongest "wet
    // gel" cue — without it a coloured nail reads matte/sticker even with the
    // softer sheen above.
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.26),
      size.width * 0.20,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.40, size.height * 0.26),
          size.width * 0.20,
          [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Free-edge reflection: a thin bright band just below the tip, as a real
    // nail catches light along its rounded free edge.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.03),
          Offset(0, size.height * 0.17),
          [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Skin-blending edge: a soft DARK inner rim (micro contact shadow), not a
    // white halo. A white outline made the nail pop off the skin like a sticker;
    // a faint dark rim lets the edge recede into the finger instead.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1),
    );
    canvas.restore();
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
  final ImageProvider image;
  final double opacity;
  final NailShape shape;

  /// The measured photo light. The design artwork is tinted by this so it sits
  /// in the same light as the hand. Defaults to no adjustment.
  final AmbientLight ambient;

  const NailOverlay({
    super.key,
    required this.image,
    this.opacity = 0.92,
    this.shape = NailShape.almond,
    this.ambient = AmbientLight.neutral,
  });

  @override
  Widget build(BuildContext context) {
    // BoxFit.cover so the design fills the whole nail silhouette; the artwork is
    // scaled, never stretched out of proportion.
    Widget design = Image(image: image, fit: BoxFit.cover);
    // Match the design to the photo's ambient light (dim/warm/cool) so it reads
    // as painted-in-scene, not pasted-on. The gloss highlights are added AFTER
    // this in the finish painter, so nails stay glossy even in a dim room.
    if (!ambient.isNeutral) {
      design = ColorFiltered(colorFilter: ambient.filter, child: design);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ContactShadowPainter(shape)),
        Opacity(
          opacity: opacity,
          child: ClipPath(
            clipper: _NailClipper(shape),
            child: design,
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
