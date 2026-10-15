import 'dart:typed_data';
import 'dart:ui';

import 'package:comeback_app/services/still_hand_frames.dart';
import 'package:flutter_test/flutter_test.dart';

/// A straight port of the plugin's decoder, `MyHandLandmarker.yuvToRgbBitmap`
/// (hand_landmarker 3.0.1), with uvPixelStride = 1. Whatever [rgbaToI420]
/// produces has to come back out of THIS as the original picture, because this
/// is what the detector actually looks at.
Uint8List kotlinDecode(I420Frame f) {
  final out = Uint8List(f.width * f.height * 4);
  final uvStride = f.width >> 1;
  int clampHi(int x) => x < 0 ? 0 : (x > 262143 ? 262143 : x);
  for (int j = 0; j < f.height; j++) {
    for (int i = 0; i < f.width; i++) {
      final uvo = (j ~/ 2) * uvStride + (i ~/ 2);
      final y = (f.y[j * f.width + i] & 0xFF) - 16;
      final u = (f.u[uvo] & 0xFF) - 128;
      final v = (f.v[uvo] & 0xFF) - 128;
      final y1192 = y < 0 ? 0 : 1192 * y;
      final r = clampHi(y1192 + 1634 * v);
      final g = clampHi(y1192 - 833 * v - 400 * u);
      final b = clampHi(y1192 + 2066 * u);
      final o = (j * f.width + i) * 4;
      out[o] = (r << 6) >> 16 & 0xFF;
      out[o + 1] = (g >> 2) >> 8 & 0xFF;
      out[o + 2] = (b >> 10) & 0xFF;
      out[o + 3] = 255;
    }
  }
  return out;
}

RgbaFrame gradient(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      // Smooth in both directions, plus a skin-ish base, so chroma
      // subsampling is a fair test rather than a worst case.
      px[o] = (150 + 90 * x / w).round();
      px[o + 1] = (100 + 80 * y / h).round();
      px[o + 2] = (80 + 60 * (x + y) / (w + h)).round();
      px[o + 3] = 255;
    }
  }
  return RgbaFrame(px, w, h);
}

void main() {
  group('RGB to YUV for the detector', () {
    test('survives the plugin decoder — what the detector sees is the photo',
        () {
      final src = gradient(64, 48);
      final yuv = rgbaToI420(src);
      final back = kotlinDecode(yuv);
      double total = 0;
      int worst = 0;
      for (int i = 0; i < back.length; i += 4) {
        for (int c = 0; c < 3; c++) {
          final d = (back[i + c] - src.rgba[i + c]).abs();
          total += d;
          if (d > worst) worst = d;
        }
      }
      final mean = total / (back.length / 4 * 3);
      // Measured offline on Ashlyn's photo through the same pair: mean 0.87.
      expect(mean, lessThan(2.0), reason: 'mean channel error $mean');
      expect(worst, lessThanOrEqualTo(8), reason: 'worst channel error');
    });

    test('control: FULL-range YUV through the same decoder is visibly wrong',
        () {
      // Proves the test above can fail. The plugin's decoder is limited range,
      // so encoding full range (Y = luma with no 16 offset or 219 scale) comes
      // back with blown contrast — exactly the mistake the test must catch.
      final src = gradient(64, 48);
      final good = rgbaToI420(src);
      final fullY = Uint8List.fromList([
        for (int j = 0; j < good.height; j++)
          for (int i = 0; i < good.width; i++)
            () {
              final o = (j * src.width + i) * 4;
              return (0.299 * src.rgba[o] +
                      0.587 * src.rgba[o + 1] +
                      0.114 * src.rgba[o + 2])
                  .round();
            }(),
      ]);
      final back = kotlinDecode(
          I420Frame(fullY, good.u, good.v, good.width, good.height));
      double total = 0;
      for (int i = 0; i < back.length; i += 4) {
        total += (back[i] - src.rgba[i]).abs();
      }
      expect(total / (back.length / 4), greaterThan(4.0));
    });

    test('odd sizes are trimmed to even, never read past the end', () {
      final yuv = rgbaToI420(gradient(31, 17));
      expect(yuv.width, 30);
      expect(yuv.height, 16);
      expect(yuv.y.length, 30 * 16);
      expect(yuv.u.length, 15 * 8);
    });
  });

  group('framing passes', () {
    test('the whole frame is tried first', () {
      // Every photo that works today is found by the first pass, so nothing
      // that already worked can be made to work differently.
      final p = kStillDetectPasses.first;
      expect(p.crop, const Rect.fromLTRB(0, 0, 1, 1));
    });

    // The real risk in this file is not a crash, it is cutting the frame one
    // way and mapping the answer back another, which puts every nail in the
    // wrong place by a consistent offset. So: mark one pixel in the photo,
    // cut the frame, FIND the pixel in the cut frame, map it back, and it must
    // land where it started.
    for (final pass in kStillDetectPasses) {
      test('a point found in "${pass.name}" maps back onto the photo', () {
        const w = 200, h = 150;
        for (final target in const [
          Offset(100, 75), // centre
          Offset(60, 40),
          Offset(140, 110),
        ]) {
          final px = Uint8List(w * h * 4);
          final o = (target.dy.toInt() * w + target.dx.toInt()) * 4;
          px[o] = 255;
          px[o + 3] = 255;

          final framed = framePass(RgbaFrame(px, w, h), pass);
          int? fx, fy;
          for (int y = 0; y < framed.height && fx == null; y++) {
            for (int x = 0; x < framed.width; x++) {
              if (framed.rgba[(y * framed.width + x) * 4] == 255) {
                fx = x;
                fy = y;
                break;
              }
            }
          }
          if (fx == null) {
            // This window does not contain the point; nothing to map.
            continue;
          }
          // The detector reports the CENTRE of a pixel as (x+0.5)/width.
          final norm = Offset((fx + 0.5) / framed.width,
              (fy! + 0.5) / framed.height);
          final mapped = passToPhoto([norm], pass, w, h).single;
          expect(mapped.dx * w, closeTo(target.dx + 0.5, 0.75));
          expect(mapped.dy * h, closeTo(target.dy + 0.5, 0.75));
        }
      });
    }

    test('the centre point is inside every window, so each pass is tested',
        () {
      for (final pass in kStillDetectPasses) {
        if (pass.crop == null) continue;
        expect(pass.crop!.contains(const Offset(0.5, 0.5)), isTrue,
            reason: pass.name);
      }
    });
  });

  group('choosing a hand', () {
    List<Offset> handIn(Rect r) => [
          for (int i = 0; i < 21; i++)
            Offset(r.left + r.width * (i % 5) / 4,
                r.top + r.height * (i ~/ 5) / 4),
        ];

    test('picks the biggest hand, not the first', () {
      final small = handIn(const Rect.fromLTWH(0.0, 0.0, 0.1, 0.1));
      final big = handIn(const Rect.fromLTWH(0.3, 0.2, 0.5, 0.6));
      expect(largestHand([small, big]), 1);
    });

    test('none found is -1, and a partial hand is ignored', () {
      expect(largestHand(const []), -1);
      expect(largestHand([const [Offset.zero, Offset(1, 1)]]), -1);
    });
  });
}
