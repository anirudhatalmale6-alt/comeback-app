import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:comeback_app/services/image_stats.dart';

void main() {
  test('dark plane → low brightness, no glare', () {
    final bytes = Uint8List(100 * 100)..fillRange(0, 100 * 100, 20);
    final s = computeLumaStats(bytes, 100, 100, 100, step: 1);
    expect(s.brightness, closeTo(20, 0.001));
    expect(s.glareFrac, 0);
  });

  test('all-white plane → full brightness and full glare', () {
    final bytes = Uint8List(100 * 100)..fillRange(0, 100 * 100, 255);
    final s = computeLumaStats(bytes, 100, 100, 100, step: 1);
    expect(s.brightness, closeTo(255, 0.001));
    expect(s.glareFrac, closeTo(1.0, 0.001));
  });

  test('half glare pixels → ~0.5 glare fraction', () {
    // Left half white (glare), right half mid-grey.
    final bytes = Uint8List(100 * 100);
    for (int y = 0; y < 100; y++) {
      for (int x = 0; x < 100; x++) {
        bytes[y * 100 + x] = x < 50 ? 255 : 100;
      }
    }
    final s = computeLumaStats(bytes, 100, 100, 100, step: 1);
    expect(s.glareFrac, closeTo(0.5, 0.02));
    expect(s.brightness, closeTo((255 + 100) / 2, 1.0));
  });

  test('respects row stride (padding beyond width is ignored)', () {
    const w = 10, h = 10, stride = 16;
    final bytes = Uint8List(stride * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < stride; x++) {
        // Real pixels = 200; padding = 255 (would skew glare if counted).
        bytes[y * stride + x] = x < w ? 200 : 255;
      }
    }
    final s = computeLumaStats(bytes, w, h, stride, step: 1);
    expect(s.brightness, closeTo(200, 0.001));
    expect(s.glareFrac, 0); // padding not sampled
  });

  test('empty input is safe', () {
    final s = computeLumaStats(Uint8List(0), 0, 0, 0);
    expect(s.brightness, 0);
    expect(s.glareFrac, 0);
  });
}
