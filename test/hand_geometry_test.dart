import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:comeback_app/services/hand_geometry.dart';
import 'package:comeback_app/services/capture_conditions.dart';

// A plausible spread right hand inside a 400x600 frame.
List<Offset> _spreadHand() => const [
      Offset(200, 480), // 0 wrist
      Offset(170, 450), Offset(150, 420), Offset(125, 390), Offset(110, 360), // thumb
      Offset(170, 300), Offset(160, 260), Offset(155, 220), Offset(150, 180), // index
      Offset(200, 300), Offset(200, 250), Offset(200, 205), Offset(200, 160), // middle
      Offset(240, 305), Offset(245, 260), Offset(248, 220), Offset(250, 180), // ring
      Offset(285, 320), Offset(292, 285), Offset(295, 250), Offset(300, 210), // pinky
    ];

void main() {
  group('computeNailPoses', () {
    test('vertical finger → zero rotation, correct length and centre', () {
      final lm = List<Offset>.filled(21, Offset.zero);
      lm[8] = const Offset(100, 100); // index tip
      lm[7] = const Offset(100, 150); // index joint (below)
      final poses = computeNailPoses(lm);
      expect(poses.length, 1); // only the index finger is non-degenerate
      final p = poses.first;
      expect(p.rotation.abs(), lessThan(1e-9));
      expect(p.length, closeTo(50 * kNailLengthFactor, 0.01));
      expect(p.width, closeTo(50 * kNailLengthFactor * kNailWidthFactor, 0.01));
      // Centre sits back from the tip toward the joint (larger y).
      expect(p.center.dx, closeTo(100, 0.01));
      expect(p.center.dy, closeTo(100 + 50 * kNailLengthFactor * kNailBacksetFactor, 0.01));
    });

    test('finger pointing right → +90° rotation', () {
      final lm = List<Offset>.filled(21, Offset.zero);
      lm[8] = const Offset(150, 100);
      lm[7] = const Offset(100, 100);
      final p = computeNailPoses(lm).first;
      expect(p.rotation, closeTo(math.pi / 2, 1e-9));
    });

    test('spread hand yields five nails, all sane sizes', () {
      final poses = computeNailPoses(_spreadHand());
      expect(poses.length, 5);
      for (final p in poses) {
        expect(p.length, greaterThan(10));
        expect(p.width, closeTo(p.length * kNailWidthFactor, 0.01));
      }
    });
  });

  group('FitTransform.contain', () {
    test('letterboxes a portrait image inside a wider box', () {
      final f = FitTransform.contain(const Size(300, 450), const Size(300, 500));
      expect(f.scale, closeTo(1.0, 1e-9)); // limited by width
      expect(f.offset.dy, closeTo(25, 1e-9)); // (500-450)/2
      expect(f.imageToBox(const Offset(0, 0)), const Offset(0, 25));
    });
  });

  group('evaluateFrame', () {
    const frame = Size(400, 600);
    test('no landmarks with good light → noHand', () {
      final r = evaluateFrame(
          landmarks: null, frameSize: frame, brightness: 120, glareFrac: 0.02);
      expect(r, CaptureCheck.noHand);
    });

    test('dark frame → tooDark before hand check', () {
      final r = evaluateFrame(
          landmarks: null, frameSize: frame, brightness: 30, glareFrac: 0.02);
      expect(r, CaptureCheck.tooDark);
    });

    test('glare → tooBright', () {
      final r = evaluateFrame(
          landmarks: _spreadHand(),
          frameSize: frame,
          brightness: 200,
          glareFrac: 0.4);
      expect(r, CaptureCheck.tooBright);
    });

    test('well-framed spread hand → ready', () {
      final r = evaluateFrame(
          landmarks: _spreadHand(),
          frameSize: frame,
          brightness: 130,
          glareFrac: 0.03);
      expect(r, CaptureCheck.ready);
      expect(r.isReady, true);
    });

    test('fingers touching → fingersTogether', () {
      final lm = List<Offset>.of(_spreadHand());
      lm[8] = const Offset(196, 180); // index tip almost on middle tip
      final r = evaluateFrame(
          landmarks: lm, frameSize: frame, brightness: 130, glareFrac: 0.03);
      expect(r, CaptureCheck.fingersTogether);
    });

    test('small hand → tooFar', () {
      // Shrink the hand toward its centre so its height fraction drops.
      final base = _spreadHand();
      final cx = 205.0, cy = 320.0;
      final lm = base
          .map((p) => Offset(cx + (p.dx - cx) * 0.3, cy + (p.dy - cy) * 0.3))
          .toList();
      final r = evaluateFrame(
          landmarks: lm, frameSize: frame, brightness: 130, glareFrac: 0.03);
      expect(r, CaptureCheck.tooFar);
    });
  });
}
