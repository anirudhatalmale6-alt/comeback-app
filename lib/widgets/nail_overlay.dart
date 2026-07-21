import 'dart:math' as math;
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

/// A procedurally-painted design: a solid [base] colour, optionally with a
/// French [tip] crescent in a second colour. This lets the customer pick ANY
/// base colour or tip colour instead of being limited to the handful of baked-in
/// PNG swatches — the nail is drawn from these colours at render time.
class ColorDesign {
  final Color base;

  /// When non-null, a French tip crescent of this colour is painted over the
  /// free-edge on top of the [base]. Null means a plain solid colour.
  final Color? tip;

  const ColorDesign(this.base, {this.tip});
}

/// The nail-tip styles a customer can pick, matching what a technician offers.
/// Nine salon shapes, ordered natural → dramatic.
enum NailShape {
  round,
  oval,
  almond,
  square,
  squoval,
  coffin,
  ballerina,
  stiletto,
  lipstick,
  flare,
  edge,
  arrowhead,
}

extension NailShapeLabel on NailShape {
  String get label {
    switch (this) {
      case NailShape.round:
        return 'Round';
      case NailShape.oval:
        return 'Oval';
      case NailShape.almond:
        return 'Almond';
      case NailShape.square:
        return 'Square';
      case NailShape.squoval:
        return 'Squoval';
      case NailShape.coffin:
        return 'Coffin';
      case NailShape.ballerina:
        return 'Ballerina';
      case NailShape.stiletto:
        return 'Stiletto';
      case NailShape.lipstick:
        return 'Lipstick';
      case NailShape.flare:
        return 'Flare';
      case NailShape.edge:
        return 'Edge';
      case NailShape.arrowhead:
        return 'Arrowhead';
    }
  }
}

/// The surface finish a customer can pick — changes how light plays on the nail.
enum NailFinish { gloss, matte, chrome, catEye, jelly, glitter, velvet }

extension NailFinishLabel on NailFinish {
  String get label {
    switch (this) {
      case NailFinish.gloss:
        return 'Gloss';
      case NailFinish.matte:
        return 'Matte';
      case NailFinish.chrome:
        return 'Chrome';
      case NailFinish.catEye:
        return 'Cat Eye';
      case NailFinish.jelly:
        return 'Jelly';
      case NailFinish.glitter:
        return 'Glitter';
      case NailFinish.velvet:
        return 'Velvet';
    }
  }

  /// How opaque the colour layer is for this finish. Jelly is translucent so the
  /// nail underneath shows through; every other finish is near-solid gel polish.
  double get opacity {
    switch (this) {
      case NailFinish.jelly:
        return 0.80;
      default:
        return 0.96;
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
Path nailSilhouette(Size s, [NailShape shape = NailShape.oval]) {
  final w = s.width, h = s.height;
  final p = Path();
  // Cuticle (bottom) - a soft curve shared by every shape.
  p.moveTo(w * 0.18, h * 0.88);
  p.quadraticBezierTo(w * 0.50, h * 1.02, w * 0.82, h * 0.88);
  switch (shape) {
    case NailShape.round:
      // Gently tapered sides curving into a semicircular tip.
      p.cubicTo(w * 0.90, h * 0.64, w * 0.92, h * 0.42, w * 0.86, h * 0.24);
      p.cubicTo(w * 0.80, h * 0.04, w * 0.20, h * 0.04, w * 0.14, h * 0.24);
      p.cubicTo(w * 0.08, h * 0.42, w * 0.10, h * 0.64, w * 0.18, h * 0.88);
      break;
    case NailShape.oval:
      // Full egg shape: bellies wide at the middle then rounds softly to the
      // tip (no point). The most natural, flattering everyday shape.
      p.cubicTo(w * 0.98, h * 0.62, w * 0.94, h * 0.28, w * 0.70, h * 0.10);
      p.cubicTo(w * 0.58, h * 0.02, w * 0.42, h * 0.02, w * 0.30, h * 0.10);
      p.cubicTo(w * 0.06, h * 0.28, w * 0.02, h * 0.62, w * 0.18, h * 0.88);
      break;
    case NailShape.almond:
      // Belly out at the sides, then taper to a soft point at the tip so it
      // reads as an almond rather than a plain oval.
      p.cubicTo(w * 0.94, h * 0.68, w * 0.88, h * 0.40, w * 0.66, h * 0.14);
      p.quadraticBezierTo(w * 0.54, 0, w * 0.50, 0);
      p.quadraticBezierTo(w * 0.46, 0, w * 0.34, h * 0.14);
      p.cubicTo(w * 0.12, h * 0.40, w * 0.06, h * 0.68, w * 0.18, h * 0.88);
      break;
    case NailShape.square:
      // Near-parallel sides, flat free-edge with softly rounded corners.
      p.cubicTo(w * 0.88, h * 0.62, w * 0.90, h * 0.40, w * 0.90, h * 0.20);
      p.cubicTo(w * 0.90, h * 0.07, w * 0.81, h * 0.04, w * 0.70, h * 0.04);
      p.lineTo(w * 0.30, h * 0.04);
      p.cubicTo(w * 0.19, h * 0.04, w * 0.10, h * 0.07, w * 0.10, h * 0.20);
      p.cubicTo(w * 0.10, h * 0.40, w * 0.12, h * 0.62, w * 0.18, h * 0.88);
      break;
    case NailShape.squoval:
      // Square body but with generously rounded top corners — the "squared
      // oval" everyone asks for.
      p.cubicTo(w * 0.89, h * 0.62, w * 0.91, h * 0.40, w * 0.90, h * 0.24);
      p.cubicTo(w * 0.89, h * 0.10, w * 0.80, h * 0.05, w * 0.66, h * 0.05);
      p.lineTo(w * 0.34, h * 0.05);
      p.cubicTo(w * 0.20, h * 0.05, w * 0.11, h * 0.10, w * 0.10, h * 0.24);
      p.cubicTo(w * 0.09, h * 0.40, w * 0.11, h * 0.62, w * 0.18, h * 0.88);
      break;
    case NailShape.coffin:
      // Sides taper inwards to a flat, narrow "ballerina" tip.
      p.cubicTo(w * 0.92, h * 0.66, w * 0.85, h * 0.38, w * 0.74, h * 0.12);
      p.lineTo(w * 0.67, h * 0.05);
      p.lineTo(w * 0.33, h * 0.05);
      p.lineTo(w * 0.26, h * 0.12);
      p.cubicTo(w * 0.15, h * 0.38, w * 0.08, h * 0.66, w * 0.18, h * 0.88);
      break;
    case NailShape.ballerina:
      // Like a coffin but longer and more sharply tapered to a slimmer flat tip.
      p.cubicTo(w * 0.91, h * 0.64, w * 0.82, h * 0.34, w * 0.70, h * 0.08);
      p.lineTo(w * 0.62, h * 0.02);
      p.lineTo(w * 0.38, h * 0.02);
      p.lineTo(w * 0.30, h * 0.08);
      p.cubicTo(w * 0.18, h * 0.34, w * 0.09, h * 0.64, w * 0.18, h * 0.88);
      break;
    case NailShape.stiletto:
      // Sides taper all the way to a sharp point at the tip.
      p.cubicTo(w * 0.92, h * 0.64, w * 0.80, h * 0.34, w * 0.50, h * 0.02);
      p.cubicTo(w * 0.20, h * 0.34, w * 0.08, h * 0.64, w * 0.18, h * 0.88);
      break;
    case NailShape.lipstick:
      // A diagonal "lipstick bullet" tip: one high corner slashing down across
      // the free edge to the opposite side.
      p.cubicTo(w * 0.94, h * 0.60, w * 0.94, h * 0.34, w * 0.90, h * 0.14);
      p.lineTo(w * 0.86, h * 0.08);
      p.lineTo(w * 0.16, h * 0.34);
      p.cubicTo(w * 0.10, h * 0.56, w * 0.10, h * 0.72, w * 0.18, h * 0.88);
      break;
    case NailShape.flare:
      // "Duck"/flare: sides splay OUTWARD toward a wide, softly-rounded free
      // edge — wider at the tip than at the cuticle.
      p.cubicTo(w * 0.90, h * 0.62, w * 0.97, h * 0.34, w * 0.98, h * 0.12);
      p.quadraticBezierTo(w * 0.50, h * 0.0, w * 0.02, h * 0.12);
      p.cubicTo(w * 0.03, h * 0.34, w * 0.10, h * 0.62, w * 0.18, h * 0.88);
      break;
    case NailShape.edge:
      // Straight angular sides rising to a single central ridge/peak at the
      // tip, like a faceted "edge" nail.
      p.cubicTo(w * 0.90, h * 0.64, w * 0.78, h * 0.34, w * 0.60, h * 0.12);
      p.lineTo(w * 0.50, h * 0.0);
      p.lineTo(w * 0.40, h * 0.12);
      p.cubicTo(w * 0.22, h * 0.34, w * 0.10, h * 0.64, w * 0.18, h * 0.88);
      break;
    case NailShape.arrowhead:
      // Bellies out wide at the sides then tapers to a sharp point — a broader,
      // more dramatic point than the stiletto.
      p.cubicTo(w * 1.0, h * 0.70, w * 0.84, h * 0.42, w * 0.50, h * 0.0);
      p.cubicTo(w * 0.16, h * 0.42, w * 0.0, h * 0.70, w * 0.18, h * 0.88);
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

/// Paints the finishing touches on top of the design. Each [NailFinish] plays
/// with light differently — a wet gloss, a flat matte, a metallic chrome, a
/// magnetic cat-eye streak, a translucent jelly, sparkling glitter or a soft
/// velvet — all on top of a shared rounded-nail shading so it reads 3D. Ends
/// with a soft dark inner rim so the edge sinks into the skin (no sticker halo).
class _NailFinishPainter extends CustomPainter {
  final NailShape shape;
  final NailFinish finish;
  const _NailFinishPainter(this.shape, this.finish);

  // Convex side-shading + rounded cuticle base, shared by all finishes so the
  // nail always reads as a curved surface rather than a flat cut-out.
  void _base(Canvas canvas, Size size, Rect rect, {double sides = 0.17}) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          [
            Colors.black.withValues(alpha: sides),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: sides),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.70),
          Offset(0, size.height),
          [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.18)],
        ),
    );
  }

  void _sheen(Canvas canvas, Size size, Rect rect, double strength) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.42, size.height * 0.30),
          size.width * 0.62,
          [
            Colors.white.withValues(alpha: strength),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  void _hotspot(Canvas canvas, Size size, double strength) {
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.26),
      size.width * 0.20,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.40, size.height * 0.26),
          size.width * 0.20,
          [
            Colors.white.withValues(alpha: strength),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  void _specularStreak(Canvas canvas, Size size, Rect rect, double strength) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.32, 0),
          Offset(size.width * 0.52, 0),
          [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: strength),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  // A small, crisp specular glint — the tight bright core of a light
  // reflection that sits inside the softer hotspot and sells a wet, glassy top.
  void _glint(Canvas canvas, Size size, double cx, double cy, double r,
      double strength) {
    canvas.drawCircle(
      Offset(size.width * cx, size.height * cy),
      size.width * r,
      Paint()
        ..color = Colors.white.withValues(alpha: strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * r * 0.5),
    );
  }

  void _tipReflection(Canvas canvas, Size size, Rect rect) {
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
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape);
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(path);

    switch (finish) {
      case NailFinish.gloss:
        _base(canvas, size, rect);
        _sheen(canvas, size, rect, 0.26);
        _specularStreak(canvas, size, rect, 0.32);
        _hotspot(canvas, size, 0.58);
        // A tight bright core inside the hotspot + a small secondary reflection
        // lower down = a convincing wet, glass-coated shine.
        _glint(canvas, size, 0.40, 0.24, 0.07, 0.95);
        _glint(canvas, size, 0.60, 0.60, 0.05, 0.30);
        _tipReflection(canvas, size, rect);
        break;

      case NailFinish.jelly:
        // Translucent but very wet-looking: strong sheen and hotspot.
        _base(canvas, size, rect, sides: 0.12);
        _sheen(canvas, size, rect, 0.30);
        _specularStreak(canvas, size, rect, 0.30);
        _hotspot(canvas, size, 0.66);
        _glint(canvas, size, 0.40, 0.24, 0.07, 0.95);
        _tipReflection(canvas, size, rect);
        break;

      case NailFinish.matte:
        // Flat, no reflections. A faint even veil + gentle curvature only.
        _base(canvas, size, rect, sides: 0.20);
        canvas.drawRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.05),
        );
        break;

      case NailFinish.velvet:
        // Soft suede: a broad, directional low sheen, no hard specular.
        _base(canvas, size, rect, sides: 0.20);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, size.height * 0.10),
              Offset(0, size.height * 0.95),
              [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.10),
              ],
              [0.0, 0.45, 1.0],
            ),
        );
        break;

      case NailFinish.chrome:
        // Mirror metal reflects a room: a cool "sky" up top, a bright horizon
        // band across the middle, and a warmer, darker "floor" below — plus a
        // crisp highlight. Reads like polished chrome catching the light.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, 0),
              Offset(0, size.height),
              [
                Colors.white.withValues(alpha: 0.55),
                const Color(0xFF9FB6D6).withValues(alpha: 0.30), // cool sky
                Colors.black.withValues(alpha: 0.46),
                Colors.white.withValues(alpha: 0.55), // bright horizon
                const Color(0xFF6A5240).withValues(alpha: 0.34), // warm floor
                Colors.black.withValues(alpha: 0.34),
              ],
              [0.0, 0.24, 0.46, 0.60, 0.82, 1.0],
            ),
        );
        // A thin, crisp horizon streak where the two reflections meet.
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.05),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, size.height * 0.02),
        );
        _base(canvas, size, rect, sides: 0.20);
        _hotspot(canvas, size, 0.70);
        _glint(canvas, size, 0.40, 0.24, 0.06, 0.85);
        break;

      case NailFinish.catEye:
        // Magnetic cat-eye: a bright, narrow light bar down the length over a
        // darkened base, like light caught in the magnetic pigment.
        // Darker sides for stronger contrast, then a soft glowing bloom under a
        // thin ultra-bright core — the light "caught" in the magnetic pigment.
        canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.20));
        _base(canvas, size, rect, sides: 0.16);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(size.width * 0.28, 0),
              Offset(size.width * 0.62, 0),
              [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.0),
              ],
              [0.0, 0.5, 1.0],
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03),
        );
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.06, size.height),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, size.width * 0.015),
        );
        break;

      case NailFinish.glitter:
        // Sparkle: many tiny flecks in mixed metallic/iridescent tints (seeded
        // so they hold still between repaints), a soft sheen so they sit in a
        // shiny coat, and a few brighter flecks with tiny cross-flares.
        _base(canvas, size, rect, sides: 0.14);
        _sheen(canvas, size, rect, 0.16);
        const flecks = [
          Color(0xFFFFFFFF), Color(0xFFFFF3C4), Color(0xFFFFE08A), // silver/gold
          Color(0xFFFFD1E8), Color(0xFFCDE9FF), Color(0xFFD8FFE6), // iridescent
        ];
        final rnd = math.Random(7);
        for (int i = 0; i < 60; i++) {
          final x = rnd.nextDouble() * size.width;
          final y = rnd.nextDouble() * size.height;
          final r = 0.4 + rnd.nextDouble() * 1.2;
          final a = 0.30 + rnd.nextDouble() * 0.55;
          canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..color = flecks[rnd.nextInt(flecks.length)].withValues(alpha: a),
          );
        }
        // A handful of standout sparkles with a soft glow + a crisp cross.
        for (int i = 0; i < 6; i++) {
          final x = size.width * (0.15 + rnd.nextDouble() * 0.7);
          final y = size.height * (0.10 + rnd.nextDouble() * 0.7);
          final s = size.width * (0.05 + rnd.nextDouble() * 0.05);
          canvas.drawCircle(
            Offset(x, y),
            s * 0.9,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.6),
          );
          final p = Paint()
            ..color = Colors.white
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x - s, y), Offset(x + s, y), p);
          canvas.drawLine(Offset(x, y - s), Offset(x, y + s), p);
        }
        _hotspot(canvas, size, 0.26);
        break;
    }

    // Skin-blending edge: a soft DARK inner rim (micro contact shadow), not a
    // white halo, so the nail edge recedes into the skin.
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
      oldDelegate.shape != shape || oldDelegate.finish != finish;
}

/// A single nail: the chosen design rendered INSIDE a natural nail-shaped
/// template (mask), with a contact shadow, the chosen finish and feathered
/// edges so it reads as a real nail rather than a flat PNG pasted on the photo.
///
/// The widget fills its parent box; the caller sizes/positions/rotates it and
/// picks the [shape] and [finish].
class NailOverlay extends StatelessWidget {
  /// The design artwork (bundled asset or the customer's own upload). Null when
  /// the nail is painted from a [color] instead.
  final ImageProvider? image;

  /// A procedurally-painted colour design (solid, or a French tip). Takes
  /// precedence over [image] when set.
  final ColorDesign? color;

  /// Recolours an [image] design to this colour while keeping its light/dark
  /// structure (a gradient's fade, a glitter's sparkle, a pattern's contrast).
  /// Null leaves the artwork in its original colours. Ignored for [color].
  final Color? tint;

  /// When set, a French tip crescent of this colour is painted OVER an [image]
  /// design, so a glitter, ombré, pattern or the customer's own photo can wear a
  /// French tip on top. Ignored for a [color] design — those carry their own tip.
  final Color? frenchTip;

  /// Premade decal stickers (hearts, stars, gems…) placed on top of the design,
  /// clipped to the nail so they never bleed onto the skin. Positioned/sized
  /// relative to the nail box, so the same list reads identically on the big
  /// Studio preview and the small nail over the hand photo.
  final List<DecalSpec> decals;

  /// Freehand strokes the customer painted on the nail in the Draw tool, clipped
  /// to the nail silhouette. Points and width are normalised to the nail box so
  /// the drawing reads the same in the Studio and over the hand.
  final List<StrokeSpec> strokes;

  final NailShape shape;
  final NailFinish finish;

  /// The measured photo light. The design is tinted by this so it sits in the
  /// same light as the hand. Defaults to no adjustment.
  final AmbientLight ambient;

  const NailOverlay({
    super.key,
    this.image,
    this.color,
    this.tint,
    this.frenchTip,
    this.decals = const [],
    this.strokes = const [],
    this.shape = NailShape.oval,
    this.finish = NailFinish.gloss,
    this.ambient = AmbientLight.neutral,
  }) : assert(image != null || color != null,
            'NailOverlay needs an image or a colour to paint');

  @override
  Widget build(BuildContext context) {
    Widget design;
    if (color != null) {
      // Painted from colours; the painter clips itself to the nail silhouette.
      design = CustomPaint(painter: _ColorDesignPainter(shape, color!));
    } else {
      // BoxFit.cover so the artwork fills the whole nail silhouette; it is
      // scaled, never stretched out of proportion.
      Widget art = Image(image: image!, fit: BoxFit.cover);
      if (tint != null) {
        // Recolour the design to the chosen colour: BlendMode.color takes the
        // hue+saturation from the tint but keeps the artwork's own luminosity,
        // so a gradient still fades, glitter still sparkles and a pattern keeps
        // its contrast — just in a new colour. Done inside the clip so only the
        // nail is affected.
        art = ColorFiltered(
          colorFilter: ColorFilter.mode(tint!, BlendMode.color),
          child: art,
        );
      }
      design = ClipPath(
        clipper: _NailClipper(shape),
        child: art,
      );
      if (frenchTip != null) {
        // Stack a French tip crescent on top of the artwork (drawn under the
        // finish so the gloss/shading still plays over it, and inside the
        // ambient filter below so it shares the photo's light).
        design = Stack(
          fit: StackFit.expand,
          children: [
            design,
            CustomPaint(painter: _FrenchOverlayPainter(shape, frenchTip!)),
          ],
        );
      }
    }
    if (strokes.isNotEmpty) {
      // Freehand drawing sits on top of the base design (and French tip), under
      // the decals, clipped to the nail so paint never bleeds onto the skin.
      design = Stack(
        fit: StackFit.expand,
        children: [
          design,
          ClipPath(
            clipper: _NailClipper(shape),
            child: CustomPaint(painter: _StrokePainter(strokes)),
          ),
        ],
      );
    }
    if (decals.isNotEmpty) {
      // Decals sit on top of the design (and any French tip), clipped to the
      // nail so an off-centre sticker trims at the edge instead of spilling
      // onto the skin — matching what lands on the hand.
      design = Stack(
        fit: StackFit.expand,
        children: [
          design,
          ClipPath(
            clipper: _NailClipper(shape),
            child: _DecalLayer(decals),
          ),
        ],
      );
    }
    if (!ambient.isNeutral) {
      design = ColorFiltered(colorFilter: ambient.filter, child: design);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ContactShadowPainter(shape)),
        Opacity(opacity: finish.opacity, child: design),
        CustomPaint(painter: _NailFinishPainter(shape, finish)),
      ],
    );
  }
}

/// One premade decal placed on a nail: its artwork and where it sits, sized and
/// rotated relative to the nail box. [pos] is normalised (0..1) within the box
/// and [size] is the decal's width as a fraction of the box width, so a decal
/// keeps its relative place/size whether the nail is drawn big in the Studio or
/// small over the hand.
class DecalSpec {
  final ImageProvider image;
  final Offset pos;
  final double size;
  final double rotation;

  /// Optional recolour for the charm/decal. Applied with [BlendMode.color] so
  /// it takes on the chosen hue+saturation while keeping the artwork's own
  /// highlights and shadows (a gold bow can become a pink or blue bow, etc.).
  /// Null leaves the sticker in its original colours.
  final Color? tint;

  const DecalSpec({
    required this.image,
    required this.pos,
    required this.size,
    required this.rotation,
    this.tint,
  });
}

/// Lays a list of [DecalSpec]s over a nail box, each centred on its [pos],
/// sized to a square of [size]×box-width and rotated. Used inside [NailOverlay]
/// (clipped to the nail) so it renders identically everywhere the nail appears.
class _DecalLayer extends StatelessWidget {
  final List<DecalSpec> decals;
  const _DecalLayer(this.decals);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in decals)
              Positioned(
                left: s.pos.dx * w - s.size * w / 2,
                top: s.pos.dy * h - s.size * w / 2,
                width: s.size * w,
                height: s.size * w,
                child: Transform.rotate(
                  angle: s.rotation,
                  child: s.tint == null
                      ? Image(image: s.image, fit: BoxFit.contain)
                      : _TintedDecal(image: s.image, tint: s.tint!),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Renders a decal recoloured to [tint] while keeping BOTH the artwork's own
/// shading/highlights AND its transparency.
///
/// A plain `ColorFiltered(BlendMode.color)` recolours nicely but, with an opaque
/// tint, also turns every TRANSPARENT pixel around the sticker into solid tint
/// (output alpha = tint alpha = 1). That fills the whole decal box with a
/// coloured square, which reads as "the entire nail changed colour". Here we do
/// the colour blend into an offscreen layer and then re-apply the sticker's
/// ORIGINAL alpha with a [BlendMode.dstIn] pass, so only the charm itself is
/// recoloured and the surround stays clear.
class _TintedDecal extends StatefulWidget {
  final ImageProvider image;
  final Color tint;
  const _TintedDecal({required this.image, required this.tint});

  @override
  State<_TintedDecal> createState() => _TintedDecalState();
}

class _TintedDecalState extends State<_TintedDecal> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _img;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_TintedDecal old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    final listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _img = info.image);
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    // While the sticker decodes, show it in its original colours so it never
    // pops in as a blank box.
    if (img == null) return Image(image: widget.image, fit: BoxFit.contain);
    return CustomPaint(size: Size.infinite, painter: _TintedDecalPainter(img, widget.tint));
  }
}

class _TintedDecalPainter extends CustomPainter {
  final ui.Image image;
  final Color tint;
  const _TintedDecalPainter(this.image, this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final imgSize = Size(image.width.toDouble(), image.height.toDouble());
    final src = Offset.zero & imgSize;
    // BoxFit.contain: scale to fit inside the box, centred — matching the plain
    // Image(fit: BoxFit.contain) used for untinted decals.
    final fitted = applyBoxFit(BoxFit.contain, imgSize, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);

    canvas.saveLayer(Offset.zero & size, Paint());
    // 1. Recolour: keeps the artwork's luminosity (its shading/highlights) but
    //    takes the tint's hue+saturation. Fills the transparent surround too.
    canvas.drawImageRect(
      image, src, dst,
      Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.color),
    );
    // 2. Re-apply the sticker's ORIGINAL alpha, erasing that solid-colour fill
    //    so only the charm stays recoloured.
    canvas.drawImageRect(image, src, dst, Paint()..blendMode = BlendMode.dstIn);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TintedDecalPainter old) =>
      old.image != image || old.tint != tint;
}

/// One freehand stroke painted on a nail: its [color], its [width] as a fraction
/// of the nail-box width, and its [points] normalised (0..1) within the box, so
/// the same stroke reads identically whether the nail is drawn big in the Studio
/// or small over the hand.
class StrokeSpec {
  final Color color;
  final double width;
  final List<Offset> points;
  final bool erase;
  const StrokeSpec(
      {required this.color,
      required this.width,
      required this.points,
      this.erase = false});
}

/// Paints freehand [StrokeSpec]s inside the nail box (already clipped to the
/// silhouette by the caller), scaling the normalised points and width to the
/// actual box size so drawings render identically everywhere.
class _StrokePainter extends CustomPainter {
  final List<StrokeSpec> strokes;
  const _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Draw all strokes into one layer so eraser strokes (BlendMode.clear) can
    // rub out earlier paint on the nail without touching the design beneath.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.erase ? const Color(0xFFFFFFFF) : s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s.width * w).clamp(1.0, w)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;
      if (s.points.length == 1) {
        // A tap becomes a dot.
        final p = Offset(s.points.first.dx * w, s.points.first.dy * h);
        canvas.drawCircle(
            p,
            paint.strokeWidth / 2,
            Paint()
              ..color = s.erase ? const Color(0xFFFFFFFF) : s.color
              ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver);
        continue;
      }
      final path = Path()
        ..moveTo(s.points.first.dx * w, s.points.first.dy * h);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx * w, s.points[i].dy * h);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => old.strokes != strokes;
}

/// The French "smile line" tip band inside a [size] nail box: the crescent from
/// the free-edge (top) down to the smile line, which arcs UP in the middle (an
/// "n"/dome) so the tip is deepest at the sidewalls and rises toward the centre
/// — the way a French tip reads on a real nail. (The control point sits ABOVE
/// the side anchors, pulling the curve toward the free-edge in the middle.)
///
/// Shared by the procedural French [ColorDesign] and the French-tip OVERLAY that
/// stacks on artwork, so both read identically.
Path frenchTipBand(Size size) {
  final w = size.width, h = size.height;
  return Path()
    ..moveTo(0, h * 0.34)
    ..quadraticBezierTo(w * 0.5, h * 0.14, w, h * 0.34)
    ..lineTo(w, 0)
    ..lineTo(0, 0)
    ..close();
}

/// Paints a French tip crescent of [tip] colour ON TOP of an existing artwork
/// design (glitter, ombré, pattern or the customer's upload), clipped to the
/// nail silhouette so it stacks cleanly over the base.
class _FrenchOverlayPainter extends CustomPainter {
  final NailShape shape;
  final Color tip;
  const _FrenchOverlayPainter(this.shape, this.tip);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(nailSilhouette(size, shape));
    canvas.drawPath(frenchTipBand(size), Paint()..color = tip);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FrenchOverlayPainter old) =>
      old.shape != shape || old.tip != tip;
}

/// Paints a [ColorDesign] inside the nail silhouette: a solid base, plus a
/// French tip crescent (separated by a natural "smile line" that dips lowest in
/// the centre) when a tip colour is set. The free-edge is at the TOP of the box,
/// matching the silhouette and finish painters.
class _ColorDesignPainter extends CustomPainter {
  final NailShape shape;
  final ColorDesign design;
  const _ColorDesignPainter(this.shape, this.design);

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, Paint()..color = design.base);
    final tip = design.tip;
    if (tip != null) {
      canvas.drawPath(frenchTipBand(size), Paint()..color = tip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ColorDesignPainter old) =>
      old.shape != shape ||
      old.design.base != design.base ||
      old.design.tip != design.tip;
}

/// A small glossy preview of a [ColorDesign] on a nail silhouette, used for the
/// colour-palette swatches so a solid shows a full-colour nail and a French tip
/// shows a nude nail with the chosen tip colour.
class NailColorSwatch extends StatelessWidget {
  final ColorDesign design;
  final NailShape shape;
  const NailColorSwatch(this.design, {super.key, this.shape = NailShape.oval});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ColorSwatchPainter(shape, design));
}

class _ColorSwatchPainter extends CustomPainter {
  final NailShape shape;
  final ColorDesign design;
  const _ColorSwatchPainter(this.shape, this.design);

  @override
  void paint(Canvas canvas, Size size) {
    _ColorDesignPainter(shape, design).paint(canvas, size);
    _NailFinishPainter(shape, NailFinish.gloss).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ColorSwatchPainter old) =>
      old.shape != shape ||
      old.design.base != design.base ||
      old.design.tip != design.tip;
}

/// A small solid-colour preview of a nail [shape] with a given [finish], used in
/// the pickers so the customer sees the actual silhouette and surface (not an
/// icon) before choosing.
class NailShapePreview extends StatelessWidget {
  final NailShape shape;
  final NailFinish finish;
  final Color color;
  const NailShapePreview({
    super.key,
    this.shape = NailShape.oval,
    this.finish = NailFinish.gloss,
    this.color = const Color(0xFFDF6E8C),
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _ShapeFillPainter(shape, finish, color),
      );
}

class _ShapeFillPainter extends CustomPainter {
  final NailShape shape;
  final NailFinish finish;
  final Color color;
  const _ShapeFillPainter(this.shape, this.finish, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size, shape);
    canvas.drawPath(path, Paint()..color = color);
    // Reuse the real finish painter so previews match what lands on the nail.
    _NailFinishPainter(shape, finish).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ShapeFillPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.finish != finish ||
      oldDelegate.color != color;
}
