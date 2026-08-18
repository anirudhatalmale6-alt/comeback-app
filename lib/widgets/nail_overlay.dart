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

/// How curved the French "smile line" is, 0..1. 0 = a straight-across tip
/// (no arch); higher = a deeper, more pronounced curved smile. The default
/// reproduces the classic French smile the app has always drawn.
const double kFrenchArchDefault = 0.5;

/// A procedurally-painted design: a solid [base] colour, optionally with a
/// French [tip] crescent in a second colour. This lets the customer pick ANY
/// base colour or tip colour instead of being limited to the handful of baked-in
/// PNG swatches — the nail is drawn from these colours at render time.
class ColorDesign {
  final Color base;

  /// When non-null, a French tip crescent of this colour is painted over the
  /// free-edge on top of the [base]. Null means a plain solid colour.
  final Color? tip;

  /// Curvature of the French smile line (see [kFrenchArchDefault]). Only used
  /// when [tip] is set.
  final double arch;

  const ColorDesign(this.base, {this.tip, this.arch = kFrenchArchDefault});
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
  // The nail's base colour. Chrome uses it to build each metal's OWN mirror
  // tones (warm-gold highlights, rose-copper mids, dark-chrome shadows) instead
  // of a neutral texture tinted the same for every colour. Null → neutral.
  final Color? baseColor;
  const _NailFinishPainter(this.shape, this.finish, {this.baseColor});

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

  // An overall "wet coated" vertical sheen: a soft brightening near the free
  // edge that fades through the middle and drops to a hint of shade at the
  // cuticle — the ambient shine a gel/gloss top-coat gives across the whole
  // nail. Deliberately low-contrast and edge-to-edge so it reads as a coating,
  // not a highlight (the localised catch-lights sit on top of it).
  void _coat(Canvas canvas, Size size, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.07),
          ],
          [0.0, 0.30, 0.55, 1.0],
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

  // A soft, blurred, vertically-elongated reflection — the window-highlight you
  // see on a real wet/gel nail. Unlike [_specularStreak] (a hard full-length
  // bar that reads like a printed sticker) this is a rounded capsule confined to
  // part of the nail and heavily blurred, so it looks like light curving over a
  // glossy dome. [cx] is the horizontal centre (0..1), [topFrac]/[botFrac] the
  // vertical span, [halfW] the half-width — all as fractions of the nail size.
  void _softStreak(Canvas canvas, Size size, double cx, double topFrac,
      double botFrac, double halfW, double strength) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * (cx - halfW),
        size.height * topFrac,
        size.width * (cx + halfW),
        size.height * botFrac,
      ),
      Radius.circular(size.width * halfW),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: strength)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, size.width * halfW * 1.2),
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
        _base(canvas, size, rect, sides: 0.15);
        // A real gel top-coat reads as an overall SOFT vertical sheen (a touch
        // brighter near the free edge, fading through the middle, a hint of
        // shade at the cuticle) — the "wet coated" look — with ONE broad, very
        // diffuse window reflection and a single small catch-light. No hard bar,
        // no chalky blob.
        _coat(canvas, size, rect);
        _softStreak(canvas, size, 0.40, 0.12, 0.56, 0.11, 0.16);
        _glint(canvas, size, 0.41, 0.22, 0.038, 0.42);
        _tipReflection(canvas, size, rect);
        break;

      case NailFinish.jelly:
        // Translucent but wet-looking: the same soft coated sheen as gloss with
        // a slightly stronger broad window (jelly reads juicier), one small
        // catch-light — never a hard central bar.
        _base(canvas, size, rect, sides: 0.12);
        _coat(canvas, size, rect);
        _softStreak(canvas, size, 0.40, 0.12, 0.58, 0.11, 0.20);
        _glint(canvas, size, 0.41, 0.22, 0.04, 0.46);
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
        {
          // MIRROR CHROME. Ashlyn's note on the previous build was that chrome
          // still looked "wrong and fake — it's supposed to look more like a
          // mirror". It did, and the reason was the way it was built: soft,
          // heavily-blurred pastel patches, which is exactly what an airbrush
          // looks like, and nothing like a mirror. A mirror doesn't have its own
          // shading — it REFLECTS THE ROOM. So it has huge contrast (near-black
          // sitting right next to blown-out white), the changes between light
          // and dark are CRISP rather than feathered, the bands bend with the
          // curve of the nail, and the surface goes dark at the sides where it
          // curls away from the room. That is what this paints, in layers: the
          // reflected room as hard bands, bowed to follow the nail's dome, a
          // dark roll-off at each side with a bright wrap-around rim, and one
          // sharp catch-light. Every tone is still mixed FROM THE BASE COLOUR,
          // so silver, gold, rose gold and black each mirror as their own metal.
          final Color c = baseColor ?? const Color(0xFFC8CDD6);
          // With no base colour the nail is wearing ARTWORK (a glitter, ombré,
          // pattern or the customer's own photo) rather than a flat colour. The
          // mirror below is an opaque fill, so at full strength it would erase
          // that artwork completely; over artwork it's laid on as a translucent
          // metallic wash instead, letting the design read through it. On a
          // solid colour (the normal chrome pick) nothing changes.
          final double fill = baseColor == null ? 0.55 : 1.0;
          Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
          Color f(Color x) => x.withValues(alpha: fill);
          // Metal lives on RANGE. Mid-tones on their own read as plastic, so
          // the ladder runs all the way from an almost-black reflection to a
          // blown-out white one.
          // Kept just short of pure white on purpose: a coloured chrome (teal,
          // gold, rose) has to keep its own hue even in the hottest part of the
          // reflection, or the nail reads as a white stripe instead of metal.
          final Color blown = mix(c, Colors.white, 0.88); // clipped highlight
          final Color white = mix(c, Colors.white, 0.66);
          final Color lit = mix(c, Colors.white, 0.40);
          final Color body = mix(c, Colors.white, 0.04); // the metal itself
          final Color shade = mix(c, Colors.black, 0.42);
          final Color dark = mix(c, Colors.black, 0.60);
          final Color black = mix(c, Colors.black, 0.78); // deepest reflection

          // 1) The reflected room, as hard bands running down the nail: light
          //    bouncing up off the free edge, the dark horizon just behind it,
          //    the big blown-out ceiling light across the middle, the shadow of
          //    the hand below that, and a little bounce again at the cuticle.
          //    The stop pairs are deliberately close together — that quick
          //    light-to-dark snap is the single thing that reads as "mirror".
          //    The axis is tilted rather than straight down the nail: nothing in
          //    a real reflection lines up square with the nail, and the tilt is
          //    what stops the bands looking like printed stripes.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(size.width * 0.26, 0),
                Offset(size.width * 0.78, size.height),
                [
                  f(white),
                  f(blown),
                  f(shade),
                  f(black),
                  f(dark),
                  f(body),
                  f(lit),
                  f(blown),
                  f(blown),
                  f(lit),
                  f(shade),
                  f(dark),
                  f(shade),
                  f(lit),
                ],
                [
                  0.0,
                  0.045,
                  0.10,
                  0.18,
                  0.29,
                  0.37,
                  0.44,
                  0.50,
                  0.575,
                  0.635,
                  0.70,
                  0.81,
                  0.91,
                  1.0,
                ],
              ),
          );

          // A bowed band of reflection. The nail is domed, so every edge in the
          // reflection curves with it; drawing them as curved shapes over the
          // straight bands above is what stops the finish looking like a
          // printed gradient. Blur stays tiny on purpose — a mirror's edges are
          // sharp, and feathering them is what made the old chrome look
          // airbrushed.
          void band(double top, double bot, double bow, Color col, double a,
              double blur) {
            final p = Path()
              ..moveTo(-size.width * 0.25, size.height * top)
              ..quadraticBezierTo(size.width * 0.5, size.height * (top + bow),
                  size.width * 1.25, size.height * top)
              ..lineTo(size.width * 1.25, size.height * bot)
              ..quadraticBezierTo(size.width * 0.5, size.height * (bot + bow),
                  -size.width * 0.25, size.height * bot)
              ..close();
            canvas.drawPath(
              p,
              Paint()
                ..color = col.withValues(alpha: a * fill)
                ..maskFilter = blur <= 0
                    ? null
                    : MaskFilter.blur(BlurStyle.normal, size.width * blur),
            );
          }

          // 2) The same reflection, curved. Dark horizon under the tip, the hot
          //    light band bowing the other way across the middle, the hand's
          //    shadow low down.
          band(0.12, 0.30, 0.17, black, 0.50, 0.010);
          band(0.45, 0.58, -0.15, blown, 0.70, 0.012);
          band(0.61, 0.69, -0.12, dark, 0.32, 0.010);
          band(0.75, 0.91, 0.14, dark, 0.40, 0.018);

          // 3) Roll-off. At the sides the surface turns away from the room and
          //    stops reflecting it, so it drops almost to black — the strongest
          //    single cue that you're looking at a curved piece of metal.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, size.height * 0.5),
                Offset(size.width, size.height * 0.5),
                [
                  Colors.black.withValues(alpha: 0.62 * fill),
                  Colors.black.withValues(alpha: 0.14 * fill),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.18 * fill),
                  Colors.black.withValues(alpha: 0.68 * fill),
                ],
                [0.0, 0.10, 0.42, 0.80, 1.0],
              ),
          );

          // 4) …and right on the edge the reflection wraps back round, giving
          //    the thin brilliant rim you always see down the side of chrome.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(size.width * 0.015, 0),
                Offset(size.width * 0.14, 0),
                [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.62 * fill),
                  Colors.white.withValues(alpha: 0.0),
                ],
                [0.0, 0.42, 1.0],
              ),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(size.width * 0.88, 0),
                Offset(size.width * 0.995, 0),
                [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.40 * fill),
                  Colors.white.withValues(alpha: 0.0),
                ],
                [0.0, 0.60, 1.0],
              ),
          );

          // 5) One hard catch-light. Polished metal always throws a sharp
          //    specular streak; the soft glows of the old version never could.
          canvas.save();
          canvas.translate(size.width * 0.33, size.height * 0.46);
          canvas.rotate(-0.55);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: size.width * 0.13,
                height: size.height * 0.34,
              ),
              Radius.circular(size.width * 0.065),
            ),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55 * fill)
              ..maskFilter =
                  MaskFilter.blur(BlurStyle.normal, size.width * 0.022),
          );
          canvas.restore();

          // 6) The free edge itself: a crisp bright line, the way light catches
          //    the very lip of a chromed nail.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, 0),
                Offset(0, size.height * 0.05),
                [
                  Colors.white.withValues(alpha: 0.50 * fill),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
          );
        }
        break;

      case NailFinish.catEye:
        {
          // Galaxy / diamond magnetic cat-eye — matches Ashlyn's reference photo:
          // a DEEP, DARK base packed with a DENSE field of fine bright sparkle
          // "stars", crossed by one broad, soft, CURVED band of light (the
          // magnetic flash). The dark base + dense starry shimmer is what makes it
          // read as a magnetic cat-eye; a plain bright wash just looks like gloss.
          // Every tone is built FROM THE BASE COLOUR so a coloured cat-eye keeps
          // its own metal while still reading dark-and-starry.
          final Color c = baseColor ?? const Color(0xFF23272F);
          // As with chrome: no base colour means the nail is wearing artwork, so
          // the deep galaxy base goes on as a translucent veil rather than an
          // opaque fill and the design underneath still reads. On a solid colour
          // it stays exactly as deep and starry as before.
          final double fill = baseColor == null ? 0.55 : 1.0;
          Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
          final Color deep = mix(c, Colors.black, 0.74); // deep shadowed edges
          final Color body = mix(c, Colors.black, 0.40); // lighter core of base

          // 1) Deep base with a soft brighter pool through the middle so the
          //    sparkle and flash have some depth to sit on.
          canvas.drawRect(rect, Paint()..color = deep.withValues(alpha: fill));
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(size.width * 0.5, size.height * 0.44),
                size.width * 0.95,
                [body.withValues(alpha: fill), deep.withValues(alpha: fill)],
                [0.0, 1.0],
              ),
          );

          // 2) The magnetic FLASH — a broad, soft, curved sweep of light arcing
          //    ACROSS the nail (not a straight slit). The base colour is
          //    brightened so a coloured cat-eye flashes in its own metal, then a
          //    whiter core rides the middle of the arc.
          final Color flash = mix(c, Colors.white, 0.82);
          final band = Path()
            ..moveTo(size.width * 0.04, size.height * 0.60)
            ..quadraticBezierTo(size.width * 0.52, size.height * 0.16,
                size.width * 0.96, size.height * 0.48);
          canvas.drawPath(
            band,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.52
              ..strokeCap = StrokeCap.round
              ..color = flash.withValues(alpha: 0.34)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.17),
          );
          canvas.drawPath(
            band,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.18
              ..strokeCap = StrokeCap.round
              ..color = flash.withValues(alpha: 0.55)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
          );
          canvas.drawPath(
            band,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * 0.06
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.5)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03),
          );

          // 3) DENSE fine sparkle — the "stars". Hundreds of tiny bright specks
          //    across the whole nail (seeded so they hold still between repaints),
          //    brighter than a plain glitter so they twinkle on the dark base.
          //    Plain dots (no per-speck blur) so a full set of nails stays smooth
          //    over the live camera.
          final rnd = math.Random(42);
          for (int i = 0; i < 640; i++) {
            final x = rnd.nextDouble() * size.width;
            final y = rnd.nextDouble() * size.height;
            final r = 0.3 + rnd.nextDouble() * 0.85;
            final a = 0.30 + rnd.nextDouble() * 0.5;
            canvas.drawCircle(Offset(x, y), r,
                Paint()..color = Colors.white.withValues(alpha: a));
          }
          // 4) A scatter of standout STAR glints — a bright dot with a small,
          //    fine cross-flare — the diamond twinkle of a galaxy cat-eye. Kept
          //    small and few so they read as sparkle, not graphic plus-signs.
          //    Cross lines only (no blur) so it stays fast across a set of nails.
          for (int i = 0; i < 30; i++) {
            final x = rnd.nextDouble() * size.width;
            final y = rnd.nextDouble() * size.height;
            final s = size.width * (0.013 + rnd.nextDouble() * 0.028);
            final p = Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..strokeWidth = 0.7
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(Offset(x - s, y), Offset(x + s, y), p);
            canvas.drawLine(Offset(x, y - s), Offset(x, y + s), p);
            canvas.drawCircle(Offset(x, y), 0.9,
                Paint()..color = Colors.white.withValues(alpha: 0.95));
          }
        }
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
      oldDelegate.shape != shape ||
      oldDelegate.finish != finish ||
      oldDelegate.baseColor != baseColor;
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

  /// Curvature of the French smile line, 0..1 (see [kFrenchArchDefault]). Applies
  /// to both a [color] French tip and a [frenchTip] overlay on artwork.
  final double frenchArch;

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
    this.frenchArch = kFrenchArchDefault,
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
    // A chrome or cat-eye finish lays dense, near-opaque shading over the whole
    // nail, which all but erases a French tip painted underneath it. For those
    // the tip is lifted ABOVE the finish instead (see [tipOverFinish] below), so
    // it reads as a tip layered on top of the chrome — which is how it is worn.
    final bool liftTip =
        color?.tip != null && _finishCoversTip(finish);
    if (color != null) {
      // Painted from colours; the painter clips itself to the nail silhouette.
      // Apply the current French arch to the tip (if any).
      design = CustomPaint(
          painter: _ColorDesignPainter(
              shape,
              ColorDesign(color!.base,
                  tip: liftTip ? null : color!.tip, arch: frenchArch)));
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
            CustomPaint(
                painter:
                    _FrenchOverlayPainter(shape, frenchTip!, frenchArch)),
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
    // RepaintBoundary caches each finished nail as its own layer. Over the live
    // camera the set of nails is repositioned every frame to follow the hand;
    // isolating each nail lets Flutter re-composite the cached texture instead
    // of re-running the (fairly heavy) finish painters each frame, which keeps
    // the try-on smooth.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ContactShadowPainter(shape)),
          Opacity(opacity: finish.opacity, child: design),
          CustomPaint(
              painter:
                  _NailFinishPainter(shape, finish, baseColor: color?.base)),
          // The lifted French tip sits over the finish so a chrome or cat-eye
          // base still shows a clean, readable tip.
          if (liftTip)
            CustomPaint(
                painter: _FrenchTipOnTopPainter(shape, color!.tip!, frenchArch)),
        ],
      ),
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
///
/// [arch] (0..1) controls how deep and how curved the French smile is. As arch
/// grows BOTH the sidewall depth increases (the tip runs further down the nail)
/// AND the centre rises further toward the free edge (a more pronounced smile) —
/// so the whole range is arched (never a flat straight line): 0 = a gentle
/// shallow smile, 1 = a deep, dramatically arched smile that covers well past
/// halfway at the sides. [kFrenchArchDefault] is a natural mid arch.
Path frenchTipBand(Size size, [double arch = kFrenchArchDefault]) {
  final w = size.width, h = size.height;
  final t = arch.clamp(0.0, 1.0);
  // Tip depth at the sidewalls: runs from a shallow tip to well past halfway.
  final sideY = 0.30 + 0.34 * t; // 0.30 → 0.64
  // How high the smile rises toward the tip at the centre. A cubic curve with
  // both control points pulled toward the middle surfaces ~75% of this rise as
  // visible arch depth (vs ~50% for a plain quadratic) AND gives a sharper,
  // more pronounced peak — so the deep end reads as a dramatic curve, not just
  // a lower straight-ish line.
  final archAmt = 0.12 + 0.34 * t; // 0.12 → 0.46
  final ctrlY = (sideY - archAmt).clamp(0.02, 1.0); // control height near tip
  return Path()
    ..moveTo(0, h * sideY)
    ..cubicTo(w * 0.30, h * ctrlY, w * 0.70, h * ctrlY, w, h * sideY)
    ..lineTo(w, 0)
    ..lineTo(0, 0)
    ..close();
}

/// Whether [f] lays down coverage dense enough to bury a French tip painted
/// underneath it, so the tip has to be drawn over the finish instead. Chrome's
/// mirror sweeps and cat-eye's near-black galaxy both do; the lighter finishes
/// (gloss, matte, jelly…) let a tip beneath them read normally and look better
/// with their sheen playing over the tip.
bool _finishCoversTip(NailFinish f) =>
    f == NailFinish.chrome ||
    f == NailFinish.catEye ||
    f == NailFinish.glitter ||
    f == NailFinish.velvet;

/// Paints a French tip crescent that sits ON TOP of a finished nail (used when
/// the finish would otherwise bury it — see [_finishCoversTip]). The tip is a
/// coat of polish over the base, so it gets its own soft sheen rather than being
/// a flat block of colour: brightest just below the free edge, easing back to
/// the plain tip colour at the smile line.
class _FrenchTipOnTopPainter extends CustomPainter {
  final NailShape shape;
  final Color tip;
  final double arch;
  const _FrenchTipOnTopPainter(this.shape, this.tip, this.arch);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(nailSilhouette(size, shape));
    final band = frenchTipBand(size, arch);
    canvas.drawPath(band, Paint()..color = tip);
    // A gentle top-down sheen so the tip reads as glossy polish laid over the
    // base rather than a sticker. y=0 is the free edge.
    canvas.save();
    canvas.clipPath(band);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height * 0.72),
          [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.34, 1.0],
        ),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FrenchTipOnTopPainter old) =>
      old.shape != shape || old.tip != tip || old.arch != arch;
}

/// Paints a French tip crescent of [tip] colour ON TOP of an existing artwork
/// design (glitter, ombré, pattern or the customer's upload), clipped to the
/// nail silhouette so it stacks cleanly over the base.
class _FrenchOverlayPainter extends CustomPainter {
  final NailShape shape;
  final Color tip;
  final double arch;
  const _FrenchOverlayPainter(this.shape, this.tip,
      [this.arch = kFrenchArchDefault]);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(nailSilhouette(size, shape));
    canvas.drawPath(frenchTipBand(size, arch), Paint()..color = tip);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FrenchOverlayPainter old) =>
      old.shape != shape || old.tip != tip || old.arch != arch;
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
      canvas.drawPath(frenchTipBand(size, design.arch), Paint()..color = tip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ColorDesignPainter old) =>
      old.shape != shape ||
      old.design.base != design.base ||
      old.design.tip != design.tip ||
      old.design.arch != design.arch;
}

/// A small glossy preview of a [ColorDesign] on a nail silhouette, used for the
/// colour-palette swatches so a solid shows a full-colour nail and a French tip
/// shows a nude nail with the chosen tip colour.
class NailColorSwatch extends StatelessWidget {
  final ColorDesign design;
  final NailShape shape;
  final NailFinish finish;
  const NailColorSwatch(this.design,
      {super.key, this.shape = NailShape.oval, this.finish = NailFinish.gloss});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ColorSwatchPainter(shape, design, finish));
}

class _ColorSwatchPainter extends CustomPainter {
  final NailShape shape;
  final ColorDesign design;
  final NailFinish finish;
  const _ColorSwatchPainter(this.shape, this.design, this.finish);

  @override
  void paint(Canvas canvas, Size size) {
    _ColorDesignPainter(shape, design).paint(canvas, size);
    _NailFinishPainter(shape, finish, baseColor: design.base).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ColorSwatchPainter old) =>
      old.shape != shape ||
      old.finish != finish ||
      old.design.base != design.base ||
      old.design.tip != design.tip ||
      old.design.arch != design.arch;
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
    _NailFinishPainter(shape, finish, baseColor: color).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ShapeFillPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.finish != finish ||
      oldDelegate.color != color;
}
