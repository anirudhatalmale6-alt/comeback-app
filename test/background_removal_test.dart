import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comeback_app/services/background_removal.dart';

void main() {
  test('removes a solid border-connected background, keeps the subject', () {
    // A white background with a red block in the middle.
    final im = img.Image(width: 60, height: 60);
    img.fill(im, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(im,
        x1: 20, y1: 20, x2: 39, y2: 39, color: img.ColorRgb8(200, 40, 60));

    final out = removeBackground(im)!;
    final conv = out.convert(numChannels: 4);

    // Corners (background) are now transparent.
    expect(conv.getPixel(0, 0).a, 0);
    expect(conv.getPixel(59, 59).a, 0);
    // Centre of the subject stays fully opaque.
    expect(conv.getPixel(30, 30).a, 255);
  });

  test('keeps an interior region that matches the background colour', () {
    // Red subject with a WHITE hole in the middle (same colour as the bg). The
    // fill only travels in from the edges, so the hole must stay opaque.
    final im = img.Image(width: 60, height: 60);
    img.fill(im, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(im,
        x1: 15, y1: 15, x2: 44, y2: 44, color: img.ColorRgb8(200, 40, 60));
    img.fillRect(im,
        x1: 27, y1: 27, x2: 32, y2: 32, color: img.ColorRgb8(255, 255, 255));

    final out = removeBackground(im)!;
    final conv = out.convert(numChannels: 4);

    expect(conv.getPixel(0, 0).a, 0); // outer bg removed
    expect(conv.getPixel(29, 29).a, 255); // interior "hole" kept
    expect(conv.getPixel(16, 16).a, 255); // subject kept
  });

  test('bails (returns null) when the subject fills the frame', () {
    // Almost-uniform image: nothing distinct to keep.
    final im = img.Image(width: 40, height: 40);
    img.fill(im, color: img.ColorRgb8(250, 250, 250));
    expect(removeBackground(im), isNull);
  });
}
