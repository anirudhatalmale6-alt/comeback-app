import 'dart:typed_data';

/// Lightweight brightness/glare stats over a luma (grayscale) plane.
///
/// On Android camera frames are YUV_420_888; plane 0 is the luma (Y) channel,
/// one byte per pixel with a possible row stride. We sample a sparse grid so
/// this stays cheap enough to run on every frame.
class LumaStats {
  /// Mean luminance, 0–255.
  final double brightness;

  /// Fraction (0–1) of sampled pixels that are near-white (glare/reflection).
  final double glareFrac;

  const LumaStats(this.brightness, this.glareFrac);
}

/// [bytes] is the Y-plane, [width]/[height] the frame size, [rowStride] the
/// bytes per row (>= width). [glareThreshold] is the luma above which a pixel
/// counts as glare. [step] controls sampling density (every Nth pixel/row).
LumaStats computeLumaStats(
  Uint8List bytes,
  int width,
  int height,
  int rowStride, {
  int glareThreshold = 246,
  int step = 8,
}) {
  if (width <= 0 || height <= 0 || bytes.isEmpty) {
    return const LumaStats(0, 0);
  }
  int sum = 0, count = 0, glare = 0;
  for (int y = 0; y < height; y += step) {
    final rowStart = y * rowStride;
    for (int x = 0; x < width; x += step) {
      final idx = rowStart + x;
      if (idx >= bytes.length) break;
      final v = bytes[idx];
      sum += v;
      if (v >= glareThreshold) glare++;
      count++;
    }
  }
  if (count == 0) return const LumaStats(0, 0);
  return LumaStats(sum / count, glare / count);
}
