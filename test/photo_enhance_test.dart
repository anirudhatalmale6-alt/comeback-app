import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:comeback_app/services/photo_enhance.dart';

double _meanLuma(img.Image im) {
  double s = 0;
  int n = 0;
  for (final p in im) {
    s += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
    n++;
  }
  return s / n / 255.0;
}

img.Image _solid(int w, int h, int r, int g, int b) {
  final im = img.Image(width: w, height: h);
  for (final p in im) {
    im.setPixelRgb(p.x, p.y, r, g, b);
  }
  return im;
}

void main() {
  group('enhanceImage', () {
    test('preserves dimensions exactly (landmarks stay valid)', () {
      final out = enhanceImage(_solid(40, 60, 90, 90, 90));
      expect(out.width, 40);
      expect(out.height, 60);
    });

    test('lifts a dark photo toward a brighter exposure', () {
      final dark = _solid(32, 32, 55, 55, 55);
      final before = _meanLuma(dark);
      final after = _meanLuma(enhanceImage(dark));
      expect(after, greaterThan(before + 0.05));
    });

    test('leaves an already well-exposed neutral photo close to unchanged', () {
      // Mid-grey with a little texture so contrast has something to act on.
      final im = img.Image(width: 32, height: 32);
      for (final p in im) {
        final v = 140 + ((p.x + p.y) % 8) - 4;
        im.setPixelRgb(p.x, p.y, v, v, v);
      }
      final before = _meanLuma(im);
      final after = _meanLuma(enhanceImage(im));
      expect((after - before).abs(), lessThan(0.10));
    });

    test('neutralises a colour cast (gray-world white balance)', () {
      // A warm/yellow cast: red high, blue low.
      final cast = _solid(32, 32, 170, 140, 90);
      final out = enhanceImage(cast);
      double rs = 0, bs = 0;
      int n = 0;
      for (final p in out) {
        rs += p.r;
        bs += p.b;
        n++;
      }
      final beforeGap = (170 - 90).toDouble();
      final afterGap = (rs / n) - (bs / n);
      // The red/blue gap should shrink after white balance.
      expect(afterGap, lessThan(beforeGap));
    });

    test('enhanceJpgBytes round-trips and returns a decodable JPEG', () {
      final src = img.encodeJpg(_solid(24, 24, 60, 70, 80));
      final out = enhanceJpgBytes(src);
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, 24);
      expect(decoded.height, 24);
    });
  });
}
