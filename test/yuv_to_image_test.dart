import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:comeback_app/services/yuv_to_image.dart';
import 'package:comeback_app/services/hand_geometry.dart';

/// Builds a flat YUV420 frame (uvPixelStride 1, tight row strides) whose Y plane
/// is filled from [yOf] and whose chroma is neutral unless [uOf]/[vOf] given.
YuvFrame _frame(
  int w,
  int h, {
  required int Function(int col, int row) yOf,
  int Function(int col, int row)? uOf,
  int Function(int col, int row)? vOf,
  int turns = 0,
}) {
  final y = Uint8List(w * h);
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      y[r * w + c] = yOf(c, r);
    }
  }
  final cw = w ~/ 2, ch = h ~/ 2;
  final u = Uint8List(cw * ch);
  final v = Uint8List(cw * ch);
  for (var r = 0; r < ch; r++) {
    for (var c = 0; c < cw; c++) {
      u[r * cw + c] = uOf?.call(c, r) ?? 128;
      v[r * cw + c] = vOf?.call(c, r) ?? 128;
    }
  }
  return YuvFrame(
    y: y,
    u: u,
    v: v,
    width: w,
    height: h,
    yRowStride: w,
    uvRowStride: cw,
    uvPixelStride: 1,
    rotationTurns: turns,
  );
}

void main() {
  group('yuvFrameToImage colours', () {
    test('neutral chroma with mid luma → grey', () {
      final im = yuvFrameToImage(_frame(4, 4, yOf: (_, __) => 128));
      final p = im.getPixel(0, 0);
      expect(p.r, closeTo(128, 1));
      expect(p.g, closeTo(128, 1));
      expect(p.b, closeTo(128, 1));
    });

    test('full luma → white, zero luma → black', () {
      final white = yuvFrameToImage(_frame(4, 4, yOf: (_, __) => 255));
      expect(white.getPixel(0, 0).r, 255);
      expect(white.getPixel(0, 0).g, 255);
      expect(white.getPixel(0, 0).b, 255);
      final black = yuvFrameToImage(_frame(4, 4, yOf: (_, __) => 0));
      expect(black.getPixel(0, 0).r, 0);
      expect(black.getPixel(0, 0).b, 0);
    });

    test('high V reads red-ish, high U reads blue-ish', () {
      final red = yuvFrameToImage(
          _frame(4, 4, yOf: (_, __) => 128, vOf: (_, __) => 210));
      final rp = red.getPixel(0, 0);
      expect(rp.r, greaterThan(rp.g));
      expect(rp.r, greaterThan(rp.b));
      final blue = yuvFrameToImage(
          _frame(4, 4, yOf: (_, __) => 128, uOf: (_, __) => 210));
      final bp = blue.getPixel(0, 0);
      expect(bp.b, greaterThan(bp.r));
      expect(bp.b, greaterThan(bp.g));
    });
  });

  group('rotation matches rotateNormalized', () {
    // A distinctly-placed bright pixel in an otherwise dark sensor frame must
    // land where rotateNormalized would send its normalized coordinate, so the
    // photo and the landmarks rotate the SAME way.
    test('one clockwise turn maps the marker consistently', () {
      const w = 4, h = 6, col = 1, row = 0;
      final im = yuvFrameToImage(_frame(
        w,
        h,
        yOf: (c, r) => (c == col && r == row) ? 255 : 0,
        turns: 1,
      ));
      // After one CW turn the frame is H wide, W tall.
      expect(im.width, h);
      expect(im.height, w);
      // Predict via the landmark transform, using pixel centres.
      final n = rotateNormalized(
        Offset((col + 0.5) / w, (row + 0.5) / h),
        1,
      );
      final ex = (n.dx * im.width).floor();
      final ey = (n.dy * im.height).floor();
      // The marker pixel is the brightest; confirm it sits at the predicted cell.
      expect(im.getPixel(ex, ey).r, greaterThan(200));
    });

    test('four turns return to the original orientation', () {
      final f = _frame(4, 6, yOf: (c, r) => (c == 1 && r == 0) ? 255 : 0);
      var im = yuvFrameToImage(f);
      final w0 = im.width, h0 = im.height;
      final f4 = YuvFrame(
        y: f.y,
        u: f.u,
        v: f.v,
        width: f.width,
        height: f.height,
        yRowStride: f.yRowStride,
        uvRowStride: f.uvRowStride,
        uvPixelStride: f.uvPixelStride,
        rotationTurns: 4,
      );
      final im4 = yuvFrameToImage(f4);
      expect(im4.width, w0);
      expect(im4.height, h0);
      expect(im4.getPixel(1, 0).r, greaterThan(200));
    });
  });
}
