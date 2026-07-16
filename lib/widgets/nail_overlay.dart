import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Builds the silhouette of a natural nail inside a [size] box.
///
/// The shape is an almond/oval: a rounded cuticle across the BOTTOM edge and a
/// rounded free-edge (tip) across the TOP, with gently tapered sides. Keeping
/// the cuticle at the bottom lets callers anchor scaling/rotation there, exactly
/// as a real nail grows from its base.
Path nailSilhouette(Size s) {
  final w = s.width, h = s.height;
  final p = Path();
  // Cuticle (bottom) - a soft curve.
  p.moveTo(w * 0.18, h * 0.88);
  p.quadraticBezierTo(w * 0.50, h * 1.02, w * 0.82, h * 0.88);
  // Right side up towards the tip.
  p.cubicTo(w * 0.95, h * 0.72, w * 0.97, h * 0.48, w * 0.90, h * 0.28);
  // Rounded free edge (tip) across the top.
  p.cubicTo(w * 0.82, h * 0.05, w * 0.18, h * 0.05, w * 0.10, h * 0.28);
  // Left side back down to the cuticle.
  p.cubicTo(w * 0.03, h * 0.48, w * 0.05, h * 0.72, w * 0.18, h * 0.88);
  p.close();
  return p;
}

class _NailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => nailSilhouette(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Paints a soft contact shadow beneath the nail so it grounds onto the skin
/// instead of floating like a sticker.
class _ContactShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size).shift(const Offset(0, 1.5));
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the finishing touches on top of the design: a glossy highlight near
/// the tip, a subtle darkened cuticle for depth, and a feathered rim so the
/// edge blends into the surrounding skin rather than ending in a hard line.
class _NailFinishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = nailSilhouette(size);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A single nail: the chosen design rendered INSIDE a natural nail-shaped
/// template (mask), with a contact shadow, gloss and feathered edges so it
/// reads as a real nail rather than a flat PNG pasted on the photo.
///
/// The widget fills its parent box; the caller sizes/positions/rotates it.
class NailOverlay extends StatelessWidget {
  final String asset;
  final double opacity;
  const NailOverlay({super.key, required this.asset, this.opacity = 0.92});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ContactShadowPainter()),
        Opacity(
          opacity: opacity,
          child: ClipPath(
            clipper: _NailClipper(),
            // BoxFit.cover so the design fills the whole nail silhouette; the
            // artwork is scaled, never stretched out of proportion.
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
        CustomPaint(painter: _NailFinishPainter()),
      ],
    );
  }
}
