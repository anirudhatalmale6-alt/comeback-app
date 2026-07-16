import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comeback_app/widgets/nail_overlay.dart';

void main() {
  const box = Size(100, 150);

  test('every shape has a label', () {
    for (final s in NailShape.values) {
      expect(s.label.isNotEmpty, true);
    }
  });

  test('each silhouette stays inside its box and is non-degenerate', () {
    for (final s in NailShape.values) {
      final b = nailSilhouette(box, s).getBounds();
      // The cuticle curve bulges a hair past the bottom by design; allow a
      // small margin but nothing may escape the sides or the top.
      expect(b.left, greaterThanOrEqualTo(-1), reason: '${s.label} left');
      expect(b.right, lessThanOrEqualTo(box.width + 1), reason: '${s.label} right');
      expect(b.top, greaterThanOrEqualTo(-1), reason: '${s.label} top');
      expect(b.bottom, lessThanOrEqualTo(box.height + 3), reason: '${s.label} bottom');
      // Must actually occupy most of the box height and a real width.
      expect(b.height, greaterThan(box.height * 0.7), reason: '${s.label} height');
      expect(b.width, greaterThan(box.width * 0.5), reason: '${s.label} width');
    }
  });

  test('a point near the flat tip is inside square but outside stiletto', () {
    // Just below the top edge, off to the side: filled for a flat/square tip,
    // empty for a pointed stiletto tip.
    const sidePoint = Offset(20, 12);
    expect(nailSilhouette(box, NailShape.square).contains(sidePoint), true);
    expect(nailSilhouette(box, NailShape.stiletto).contains(sidePoint), false);
  });
}
