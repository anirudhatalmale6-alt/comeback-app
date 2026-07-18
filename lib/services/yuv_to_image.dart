import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A raw YUV420 camera frame, flattened into plain data so it can be handed to
/// a background isolate (via `compute`) and unit-tested WITHOUT the camera
/// package. Android delivers hand-detection frames in this format; we keep the
/// exact frame detection ran on and turn IT into the photo, so the landmarks
/// line up with the saved image by construction (no separate still, no drift).
class YuvFrame {
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int width;
  final int height;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  /// Clockwise quarter-turns to bring the sensor frame upright. Must match the
  /// turns applied to the landmarks (see [rotateNormalized]).
  final int rotationTurns;

  const YuvFrame({
    required this.y,
    required this.u,
    required this.v,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotationTurns,
  });
}

/// Converts a [YuvFrame] to an upright RGB [img.Image]. Pure and deterministic
/// so it can be verified with synthetic frames. The rotation convention matches
/// [rotateNormalized] in hand_geometry.dart: a sensor point at normalized
/// (nx, ny) maps to (1 - ny, nx) after one clockwise turn, etc. — verified by
/// the corner-mapping unit test.
img.Image yuvFrameToImage(YuvFrame f) {
  final out = img.Image(width: f.width, height: f.height);
  final y = f.y, u = f.u, v = f.v;
  for (var row = 0; row < f.height; row++) {
    final yBase = row * f.yRowStride;
    final uvRow = (row >> 1) * f.uvRowStride;
    for (var col = 0; col < f.width; col++) {
      final yp = y[yBase + col];
      final uvIndex = uvRow + (col >> 1) * f.uvPixelStride;
      final up = u[uvIndex] - 128;
      final vp = v[uvIndex] - 128;
      // BT.601 full-range YUV → RGB.
      var r = (yp + 1.370705 * vp).round();
      var g = (yp - 0.337633 * up - 0.698001 * vp).round();
      var b = (yp + 1.732446 * up).round();
      if (r < 0) {
        r = 0;
      } else if (r > 255) {
        r = 255;
      }
      if (g < 0) {
        g = 0;
      } else if (g > 255) {
        g = 255;
      }
      if (b < 0) {
        b = 0;
      } else if (b > 255) {
        b = 255;
      }
      out.setPixelRgb(col, row, r, g, b);
    }
  }
  return _rotate(out, f.rotationTurns);
}

/// Rotates [src] by [turns] clockwise quarter-turns, matching the landmark
/// convention. `image`'s copyRotate takes clockwise degrees, so a positive
/// multiple of 90 lines up with [rotateNormalized]. Corner-mapping is pinned by
/// a unit test so the photo and the landmarks can never rotate opposite ways.
img.Image _rotate(img.Image src, int turns) {
  final q = ((turns % 4) + 4) % 4;
  if (q == 0) return src;
  return img.copyRotate(src, angle: q * 90);
}

/// Convenience for the capture path: convert + JPEG-encode in one call so the
/// whole thing runs in a single `compute` hop off the UI isolate.
Uint8List encodeYuvFrameToJpg(YuvFrame f) {
  return img.encodeJpg(yuvFrameToImage(f), quality: 92);
}
