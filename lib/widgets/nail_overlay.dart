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
          // AURORA / PEARL CHROME — built from Ashlyn's reference photo of a
          // set of sky-blue chrome nails (images.jpeg, msg 2270911502) and her
          // note: "more of a colorful shine then a bright white shine".
          //
          // Worth writing down why the first three attempts missed, because it
          // wasn't a tuning problem — it was the wrong subject. I was painting
          // MIRRORED METAL: near-black next to blown-out white, hard edges, the
          // reflection of a room. That is what a chrome bumper looks like. It is
          // not what chrome POWDER on a nail looks like, and the reference is
          // unambiguous about the difference:
          //
          //   * it is LOW contrast, not high — nothing on it is near-black and
          //     nothing is pure white
          //   * the shine is COLOURED. The highlights on a blue nail come back
          //     pink, lilac and pale peach. That colour shift IS the finish; a
          //     white highlight is exactly what makes it look like cheap plastic
          //   * the transitions are SOFT and blended, not snapped
          //   * the base colour stays obvious the whole way through
          //
          // So this paints a pearl, not a mirror: the colour is rolled around
          // the hue wheel, desaturated and lifted, and washed down the nail in
          // broad soft bands, with a second shift running ACROSS the nail (the
          // reason a duochrome changes colour as you turn your hand) and a wide
          // tinted bloom over the top. Every shimmer tone is derived FROM the
          // base colour, so a blue shifts to lilac and pink, a red shifts to
          // gold and magenta, and each one shimmers as its own metal.
          //
          // …and then Ashlyn's next note was "still not shiny enough", which was
          // also fair. The colour model above was right but I'd built it with no
          // SPECULAR STRUCTURE at all, so it came out as a satin pearl. Shine is
          // not brightness — it's RANGE and EDGE. A glossy surface has a hard
          // bright reflection, a dark band pressed right up against it, a second
          // smaller catch further along, and a lit rim where the surface turns
          // away. This version keeps every colour decision above and adds all
          // four, with the bright core tinted rather than white so it stays a
          // coloured shine.
          //
          // Still deliberately blur-free — every soft edge here is a gradient
          // shader, which the GPU does for almost nothing.
          final Color c = baseColor ?? const Color(0xFFBBD9EA);
          // With no base colour the nail is wearing ARTWORK (a glitter, ombré,
          // pattern or the customer's own photo) rather than a flat colour. The
          // wash below is an opaque fill, so at full strength it would erase
          // that artwork completely; over artwork it's laid on as a translucent
          // pearl instead, letting the design read through it. On a solid colour
          // (the normal chrome pick) nothing changes.
          final double fill = baseColor == null ? 0.55 : 1.0;
          final HSVColor hsv = HSVColor.fromColor(c);

          /// One shimmer tone: the base colour rolled [deg] around the hue
          /// wheel, its saturation scaled by [satMul] and its brightness lifted
          /// [lift] of the way to full. The saturation floor matters — a silver
          /// or a black has almost no hue to roll, and without it they'd shimmer
          /// in flat grey; the floor gives them the faint rainbow that real
          /// chrome powder throws on a neutral base.
          Color irid(double deg, double satMul, double lift) => HSVColor.fromAHSV(
                fill,
                (hsv.hue + deg + 360) % 360,
                math.max(hsv.saturation * satMul, 0.10 * satMul + 0.02)
                    .clamp(0.0, 1.0),
                (hsv.value + (1 - hsv.value) * lift).clamp(0.0, 1.0),
              ).toColor();

          // The base, deepened and slightly richer. This is the DARK end of the
          // range, and the range is what makes the finish read as glossy — a
          // bright streak with nothing dark near it just looks like a pale
          // smudge. It's the nail's own colour taken down, not black, so the
          // depth arrives without the whole thing turning muddy.
          final Color deep = HSVColor.fromAHSV(
                  fill,
                  hsv.hue,
                  math.min(hsv.saturation * 1.12, 1.0),
                  // Pale colours need proportionally MORE of a drop than dark
                  // ones. A flat multiplier left the pastels with almost no
                  // shadow, so their streak had nothing to shine against and
                  // they were the only shades that still looked satin.
                  (hsv.value * (0.74 - 0.16 * hsv.value)).clamp(0, 1))
              .toColor();
          final Color body = irid(0, 0.95, 0.04); // the nail's own colour
          // The shimmer tones are blended BACK toward the base before they're
          // used. Straight hue shifts turned a maroon olive and a gold green —
          // a full rainbow, which is not what the reference is. On a real
          // chrome nail the base colour still dominates and the shifts are
          // accents playing over the top of it, so each one is mixed to taste.
          Color acc(Color x, double t) => Color.lerp(body, x, t)!;
          final Color cool = acc(irid(-40, 0.55, 0.28), 0.55); // shifts one way…
          final Color violet = acc(irid(52, 0.55, 0.36), 0.55); // …and the other
          final Color pink = acc(irid(86, 0.46, 0.44), 0.32); // the far shift
          // The highlight tone. Its hue is kept CLOSE to the base on purpose: rolled
          // far around the wheel it stopped being a highlight and became a
          // second colour — a cream-gold stripe down a red nail that read as a
          // cat-eye rather than a shine.
          final Color pearl = acc(irid(26, 0.22, 0.88), 0.90); // pale, not white
          // The specular core. It IS nearly white — a reflection of a light
          // source is always brighter and less saturated than the surface it
          // sits on, and refusing to paint one is what left this looking satin.
          // It keeps a little of the pearl's tint and it's kept NARROW, so the
          // eye still reads the shine as coloured while getting the hard bright
          // centre that says "glossy".
          final Color hot =
              Color.lerp(pearl, Colors.white, 0.55)!.withValues(alpha: fill);

          // 1) The wash down the nail. Soft, wide stops — this is a pearl
          //    turning through its colours, not a room being reflected, so
          //    nothing here snaps.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(size.width * 0.30, 0),
                Offset(size.width * 0.70, size.height),
                [deep, body, body, violet, violet, pink, body, body, cool, deep],
                const [
                  0.0, 0.09, 0.20, 0.32, 0.43, 0.53, 0.63, 0.77, 0.89, 1.0,
                ],
              ),
          );

          // 2) The second shift, running ACROSS the nail. This is the part that
          //    makes a duochrome read as a duochrome: as the surface curves away
          //    from you the colour travels, so the left edge of the nail is a
          //    different colour from the right even though it's one polish.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, size.height * 0.5),
                Offset(size.width, size.height * 0.5),
                [
                  cool.withValues(alpha: 0.32 * fill),
                  cool.withValues(alpha: 0.06 * fill),
                  pearl.withValues(alpha: 0.16 * fill),
                  pink.withValues(alpha: 0.06 * fill),
                  pink.withValues(alpha: 0.30 * fill),
                ],
                const [0.0, 0.24, 0.47, 0.72, 1.0],
              ),
          );

          // 3) The bloom: one wide, soft, TINTED highlight over the upper half.
          //    Tinted is the whole point — pull this toward white and the finish
          //    instantly looks like plastic with a torch shone on it.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(size.width * 0.44, size.height * 0.42),
                size.width * 0.66,
                [
                  pearl.withValues(alpha: 0.15 * fill),
                  pearl.withValues(alpha: 0.05 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
                const [0.0, 0.45, 1.0],
              ),
          );

          // 4) The coloured flare. In the reference the pink/lilac shift pools
          //    in the cuticle half of the nail rather than spreading evenly, so
          //    it gets its own soft pool there instead of being smeared over
          //    the whole surface.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(size.width * 0.58, size.height * 0.72),
                size.width * 0.62,
                [
                  pink.withValues(alpha: 0.42 * fill),
                  pink.withValues(alpha: 0.12 * fill),
                  pink.withValues(alpha: 0.0),
                ],
                const [0.0, 0.5, 1.0],
              ),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(size.width * 0.30, size.height * 0.62),
                size.width * 0.45,
                [
                  violet.withValues(alpha: 0.32 * fill),
                  violet.withValues(alpha: 0.0),
                ],
              ),
          );

          // 5) The core shadow — a soft dark band lying alongside where the
          //    bright streak is about to go. This is the layer I'd been missing
          //    entirely, and it does more for "shiny" than any amount of extra
          //    white: a reflection only reads as a reflection when there's
          //    something dark pressed up against it. Painted in the deepened
          //    base colour rather than black, so it adds depth, not grime.
          canvas.save();
          canvas.translate(size.width * 0.19, size.height * 0.52);
          canvas.rotate(-0.16);
          canvas.scale(1.0, 4.6);
          final double sw = size.width * 0.17;
          canvas.drawCircle(
            Offset.zero,
            sw,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset.zero,
                sw,
                [
                  deep.withValues(alpha: 0.52 * fill),
                  deep.withValues(alpha: 0.26 * fill),
                  deep.withValues(alpha: 0.0),
                ],
                const [0.0, 0.46, 1.0],
              ),
          );
          canvas.restore();

          // 6) Curvature, a little firmer than the pearl version — the sides
          //    have to turn away from the light for the rim in step 10 to have
          //    anything to sit against.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, size.height * 0.5),
                Offset(size.width, size.height * 0.5),
                [
                  Colors.black.withValues(alpha: 0.24 * fill),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.28 * fill),
                ],
                const [0.0, 0.15, 0.82, 1.0],
              ),
          );

          // 7) The gel top-coat streak, in three tiers. The soft coloured halo
          //    is the shine you see; the bright band is its body; the narrow
          //    near-white core is the actual light source. Three tiers rather
          //    than one is the difference between a pale smear and a hard wet
          //    reflection — the halo keeps it coloured, the core makes it shine.
          canvas.save();
          canvas.translate(size.width * 0.385, size.height * 0.46);
          canvas.rotate(-0.16);
          canvas.scale(1.0, 4.4);
          final double gh = size.width * 0.20;
          canvas.drawCircle(
            Offset.zero,
            gh,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset.zero,
                gh,
                [
                  pearl.withValues(alpha: 0.52 * fill),
                  pearl.withValues(alpha: 0.30 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
                const [0.0, 0.46, 1.0],
              ),
          );
          canvas.restore();

          canvas.save();
          canvas.translate(size.width * 0.37, size.height * 0.46);
          canvas.rotate(-0.16);
          canvas.scale(1.0, 4.8);
          final double gw = size.width * 0.105;
          canvas.drawCircle(
            Offset.zero,
            gw,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset.zero,
                gw,
                [
                  pearl.withValues(alpha: 0.96 * fill),
                  pearl.withValues(alpha: 0.86 * fill),
                  pearl.withValues(alpha: 0.30 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
                const [0.0, 0.40, 0.74, 1.0],
              ),
          );
          canvas.restore();

          canvas.save();
          canvas.translate(size.width * 0.362, size.height * 0.44);
          canvas.rotate(-0.16);
          canvas.scale(1.0, 12.0);
          final double gc = size.width * 0.042;
          canvas.drawCircle(
            Offset.zero,
            gc,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset.zero,
                gc,
                [
                  hot,
                  hot.withValues(alpha: 0.85 * fill),
                  hot.withValues(alpha: 0.0),
                ],
                const [0.0, 0.50, 1.0],
              ),
          );
          canvas.restore();

          // 8) A second, smaller catch-light down near the free edge, where the
          //    nail curves over. Real gloss never has exactly one reflection,
          //    and the second one is what stops the streak reading as a painted
          //    stripe.
          canvas.save();
          canvas.translate(size.width * 0.66, size.height * 0.155);
          canvas.rotate(0.72);
          canvas.scale(1.0, 2.6);
          final double sc = size.width * 0.085;
          canvas.drawCircle(
            Offset.zero,
            sc,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset.zero,
                sc,
                [
                  hot.withValues(alpha: 0.80 * fill),
                  pearl.withValues(alpha: 0.42 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
                const [0.0, 0.42, 1.0],
              ),
          );
          canvas.restore();

          // 9) The free edge catches the light — a fine, bright line right on
          //    the lip, tighter and brighter than before.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                const Offset(0, 0),
                Offset(0, size.height * 0.045),
                [
                  hot.withValues(alpha: 0.85 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
              ),
          );

          // 10) Rim light down the far side. This one is pure chrome: where the
          //     surface rolls away from you it stops showing its own colour and
          //     starts showing the light behind it, so a thin bright edge sits
          //     right against the darkest part of the nail. Painted AFTER the
          //     side shading in step 6 so it lands on top of that shadow — the
          //     dark-then-bright jump at the very edge is the whole effect.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(size.width, size.height * 0.5),
                Offset(size.width * 0.885, size.height * 0.5),
                [
                  pearl.withValues(alpha: 0.75 * fill),
                  pearl.withValues(alpha: 0.0),
                ],
              ),
          );
          // …and a much fainter one at the cuticle, where the polish rolls over
          //    the same way.
          canvas.drawRect(
            rect,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, size.height),
                Offset(0, size.height * 0.955),
                [
                  pearl.withValues(alpha: 0.34 * fill),
                  pearl.withValues(alpha: 0.0),
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
