import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device background removal for imported inspiration photos. Uses an
/// edge-seeded flood fill (a "magic eraser" for near-uniform backgrounds): it
/// samples the colour around the image border, then makes every border-connected
/// pixel that stays within a tolerance of that colour transparent, leaving the
/// subject. A short feather softens the cut edge. Works best on photos shot on a
/// plain / solid background (white card, a table, a wall) — the common case for
/// nail-art inspiration images. Interior areas that match the background (e.g. a
/// white highlight inside the subject) are KEPT because the fill only travels
/// inward from the edges. No AI and no network; pure + deterministic so it can
/// run in a background isolate via `compute` and be unit-tested.

/// Decodes [src] (JPEG/PNG bytes), removes the background, and re-encodes as a
/// PNG (with alpha). Returns the original bytes unchanged if decoding fails or
/// if removal would erase almost the whole image (background too close to the
/// subject), so the caller can use it blindly.
Uint8List removeBackgroundPng(Uint8List src) {
  final decoded = img.decodeImage(src);
  if (decoded == null) return src;
  final out = removeBackground(decoded);
  if (out == null) return src;
  return img.encodePng(out);
}

/// The core removal on a plain [img.Image]. Returns null when it judges the
/// result unusable (it ate the subject), so the caller can fall back to the
/// original. [tolerance] is the RGB colour distance (0..441) a pixel may differ
/// from the estimated background and still be treated as background.
img.Image? removeBackground(img.Image input, {double tolerance = 52}) {
  final im = input.convert(numChannels: 4);
  final w = im.width, h = im.height;
  if (w < 4 || h < 4) return null;

  // 1. Estimate the background colour as the average of the border pixels.
  double rs = 0, gs = 0, bs = 0;
  int n = 0;
  void acc(int x, int y) {
    final p = im.getPixel(x, y);
    rs += p.r;
    gs += p.g;
    bs += p.b;
    n++;
  }

  for (var x = 0; x < w; x++) {
    acc(x, 0);
    acc(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    acc(0, y);
    acc(w - 1, y);
  }
  final br = rs / n, bg = gs / n, bb = bs / n;

  double dist(num r, num g, num b) {
    final dr = r - br, dg = g - bg, db = b - bb;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  // 2. Flood fill inward from every border pixel, capturing the connected region
  //    whose colour stays within [tolerance] of the background.
  final removed = Uint8List(w * h); // 1 = background → transparent
  final queue = Queue<int>();

  void seed(int x, int y) {
    final i = y * w + x;
    if (removed[i] != 0) return;
    final p = im.getPixel(x, y);
    if (dist(p.r, p.g, p.b) <= tolerance) {
      removed[i] = 1;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  void tryVisit(int nx, int ny) {
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
    final j = ny * w + nx;
    if (removed[j] != 0) return;
    final p = im.getPixel(nx, ny);
    if (dist(p.r, p.g, p.b) <= tolerance) {
      removed[j] = 1;
      queue.add(j);
    }
  }

  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    tryVisit(x - 1, y);
    tryVisit(x + 1, y);
    tryVisit(x, y - 1);
    tryVisit(x, y + 1);
  }

  // Guard: if we'd erase (almost) everything, the subject matched the
  // background — bail so the caller keeps the original photo.
  int cut = 0;
  for (var i = 0; i < removed.length; i++) {
    if (removed[i] != 0) cut++;
  }
  if (cut / removed.length > 0.93) return null;

  // 3. Apply alpha. Background → transparent. Subject pixels that touch the cut
  //    boundary get a partial alpha scaled by how far their colour sits from the
  //    background, so the edge feathers instead of jagging.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final p = im.getPixel(x, y);
      if (removed[i] != 0) {
        p.a = 0;
        continue;
      }
      final touchesCut = (x > 0 && removed[i - 1] != 0) ||
          (x < w - 1 && removed[i + 1] != 0) ||
          (y > 0 && removed[i - w] != 0) ||
          (y < h - 1 && removed[i + w] != 0);
      if (touchesCut) {
        final t = (dist(p.r, p.g, p.b) / tolerance).clamp(0.0, 1.0);
        // t=1 (clearly subject) → opaque; near the bg colour → fade out.
        p.a = (60 + 195 * t).round().clamp(0, 255);
      }
    }
  }
  return im;
}
