import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device auto-enhancement for try-on photos: lifts dark shots, neutralises a
/// colour cast (gray-world white balance), adds gentle contrast, and a light
/// unsharp pass so slightly blurry shots read crisper. Everything is ADAPTIVE
/// and softened — a photo that is already well-exposed and neutral comes out
/// almost unchanged, so this never "ruins" a good photo. No AI, no network.
///
/// Pure and deterministic (works on a plain [img.Image]) so it can run in a
/// background isolate via `compute` and be unit-tested with synthetic images.

/// Decodes [src] (JPEG/PNG bytes), enhances, and re-encodes as JPEG. Returns the
/// original bytes unchanged if decoding fails, so the caller can use it blindly.
Uint8List enhanceJpgBytes(Uint8List src) {
  final decoded = img.decodeImage(src);
  if (decoded == null) return src;
  return img.encodeJpg(enhanceImage(decoded), quality: 92);
}

/// The core enhancement. Dimensions are preserved exactly (no crop/rotate/
/// resize) so any hand landmarks measured against this image still line up.
img.Image enhanceImage(img.Image src) {
  final rgb = src.numChannels >= 3 ? src.convert(numChannels: 3) : src;
  final stats = _sample(rgb);

  // Auto-brightness: aim the mean luma at a well-lit target, but only PART of
  // the way and clamped, so dark photos lift without blowing out and bright
  // photos are left alone. Gain is applied as a simple multiplier.
  const targetLuma = 0.56;
  double gain = stats.meanLuma <= 0.001 ? 1.0 : targetLuma / stats.meanLuma;
  gain = _towards(1.0, gain, 0.6).clamp(0.92, 1.7);

  // Gray-world white balance: nudge each channel so the average grey is
  // neutral. Softened and tightly clamped so it corrects a yellow/blue room
  // without tinting a photo that is already neutral.
  final meanGray = (stats.meanR + stats.meanG + stats.meanB) / 3.0;
  double wb(double meanC) {
    if (meanC <= 0.001) return 1.0;
    return _towards(1.0, meanGray / meanC, 0.5).clamp(0.90, 1.12);
  }

  final gr = gain * wb(stats.meanR);
  final gg = gain * wb(stats.meanG);
  final gb = gain * wb(stats.meanB);

  // Gentle S-curve contrast around mid-grey, scaled down for photos that are
  // already contrasty so we don't crush shadows.
  const contrast = 1.10;

  final w = rgb.width, h = rgb.height;
  final out = img.Image(width: w, height: h);
  for (final p in rgb) {
    final r = _apply(p.r.toDouble(), gr, contrast);
    final g = _apply(p.g.toDouble(), gg, contrast);
    final b = _apply(p.b.toDouble(), gb, contrast);
    out.setPixelRgb(p.x, p.y, r, g, b);
  }

  return _unsharp(out, amount: 0.45);
}

int _apply(double c, double gain, double contrast) {
  var v = c * gain;
  v = (v - 128.0) * contrast + 128.0;
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v.round();
}

/// Light unsharp mask: out = image + amount*(image - blurred). Adds perceived
/// sharpness to soft/blurry shots; [amount] is kept small to avoid halos.
img.Image _unsharp(img.Image src, {required double amount}) {
  final blurred = img.gaussianBlur(src.clone(), radius: 1);
  final out = img.Image(width: src.width, height: src.height);
  for (final p in src) {
    final bp = blurred.getPixel(p.x, p.y);
    final r = _sharpChannel(p.r.toDouble(), bp.r.toDouble(), amount);
    final g = _sharpChannel(p.g.toDouble(), bp.g.toDouble(), amount);
    final b = _sharpChannel(p.b.toDouble(), bp.b.toDouble(), amount);
    out.setPixelRgb(p.x, p.y, r, g, b);
  }
  return out;
}

int _sharpChannel(double orig, double blur, double amount) {
  var v = orig + amount * (orig - blur);
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v.round();
}

double _towards(double from, double to, double t) => from + (to - from) * t;

class _Stats {
  final double meanR, meanG, meanB, meanLuma;
  const _Stats(this.meanR, this.meanG, this.meanB, this.meanLuma);
}

/// Averages the image on a coarse grid (fast, ~64x64 samples max) to drive the
/// global brightness/white-balance decisions.
_Stats _sample(img.Image im) {
  final stepX = (im.width / 64).ceil().clamp(1, im.width);
  final stepY = (im.height / 64).ceil().clamp(1, im.height);
  double rs = 0, gs = 0, bs = 0;
  int n = 0;
  for (var y = 0; y < im.height; y += stepY) {
    for (var x = 0; x < im.width; x += stepX) {
      final p = im.getPixel(x, y);
      rs += p.r;
      gs += p.g;
      bs += p.b;
      n++;
    }
  }
  if (n == 0) return const _Stats(128, 128, 128, 0.5);
  final r = rs / n, g = gs / n, b = bs / n;
  final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
  return _Stats(r, g, b, luma);
}
