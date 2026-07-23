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

    test('ring and pinky nails are pulled inward toward the hand', () {
      final lm = _spreadHand();
      final poses = computeNailPoses(lm);
      // Order matches kFingerJoints: thumb, index, middle, ring, pinky.
      final ringCenter = poses[3].center;
      final pinkyCenter = poses[4].center;
      // The lateral term moves each outer nail toward its inner neighbour, so
      // its centre sits inboard (smaller x) of the raw fingertip landmark.
      expect(ringCenter.dx, lessThan(lm[kRingTipIndex].dx));
      expect(pinkyCenter.dx, lessThan(lm[kPinkyTipIndex].dx));
    });

    test('thumb rides up onto the nail bed (past the tip landmark)', () {
      final lm = List<Offset>.filled(21, Offset.zero);
      lm[4] = const Offset(100, 100); // thumb tip
      lm[3] = const Offset(100, 150); // thumb joint below (finger points up)
      final p = computeNailPoses(lm).first;
      final backDist = p.center.dy - 100; // +y is toward the joint (down)
      expect(backDist,
          closeTo(50 * kNailLengthFactor * kNailThumbBacksetFactor, 0.01));
      // Negative backset lifts the thumb nail ABOVE the tip (toward the bed),
      // well up from where the default backset would leave it.
      expect(backDist, lessThan(0));
      expect(backDist, lessThan(50 * kNailLengthFactor * kNailBacksetFactor));
    });

    test('pinky rides up onto the nail bed (past the tip landmark)', () {
      final lm = List<Offset>.filled(21, Offset.zero);
      lm[20] = const Offset(300, 100); // pinky tip
      lm[19] = const Offset(300, 150); // pinky joint below (finger points up)
      // Neighbour (ring tip) placed straight left so the lateral pull is purely
      // horizontal and doesn't touch the vertical backset check below.
      lm[16] = const Offset(250, 100);
      final p = computeNailPoses(lm).last;
      final backDist = p.center.dy - 100; // +y is toward the joint (down)
      // Negative pinky backset lifts the nail ABOVE the tip, higher than both the
      // default and the old positive pinky value would.
      expect(backDist, lessThan(0));
      expect(backDist, lessThan(50 * kNailLengthFactor * kNailBacksetFactor));
    });
  });

  group('rotateNormalized', () {
    const p = Offset(0.2, 0.3);
    test('0 turns is identity', () {
      expect(rotateNormalized(p, 0), p);
    });
    test('four 90° turns return to start', () {
      var q = p;
      for (var i = 0; i < 4; i++) {
        q = rotateNormalized(q, 1);
      }
      expect(q.dx, closeTo(p.dx, 1e-12));
      expect(q.dy, closeTo(p.dy, 1e-12));
    });
    test('180 twice returns to start; stays in unit square', () {
      final r = rotateNormalized(rotateNormalized(p, 2), 2);
      expect(r.dx, closeTo(p.dx, 1e-12));
      expect(r.dy, closeTo(p.dy, 1e-12));
      final s = rotateNormalized(p, 1);
      expect(s.dx, inInclusiveRange(0.0, 1.0));
      expect(s.dy, inInclusiveRange(0.0, 1.0));
    });
    test('negative turns normalize (−1 == 3)', () {
      expect(rotateNormalized(p, -1), rotateNormalized(p, 3));
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
