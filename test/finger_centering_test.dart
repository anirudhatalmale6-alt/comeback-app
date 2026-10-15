import 'dart:typed_data';
import 'dart:ui';

import 'package:comeback_app/services/finger_centering.dart';
import 'package:comeback_app/services/hand_geometry.dart';
import 'package:comeback_app/services/still_hand_frames.dart';
import 'package:flutter_test/flutter_test.dart';

const int kW = 400, kH = 500;
const List<int> kBackground = [120, 90, 70]; // a wooden table
const List<int> kSkin = [230, 200, 185];

// Five upright fingers, 40 px wide, 60 px apart (so 20 px gaps), over a palm.
const List<double> kFingerX = [80, 140, 200, 260, 320];
const double kFingerW = 40;
const int kTipY = 60, kKnuckleY = 330;

/// Draws a top-down hand: five fingers and a palm, on a table.
RgbaFrame hand({
  List<int> background = kBackground,
  Map<int, List<int>> fingerColour = const {},
}) {
  final px = Uint8List(kW * kH * 4);
  void fill(int x0, int y0, int x1, int y1, List<int> c) {
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final o = (y * kW + x) * 4;
        px[o] = c[0];
        px[o + 1] = c[1];
        px[o + 2] = c[2];
        px[o + 3] = 255;
      }
    }
  }

  fill(0, 0, kW, kH, background);
  fill(50, kKnuckleY - 10, 350, kH, kSkin); // back of the hand
  for (int f = 0; f < 5; f++) {
    final x0 = (kFingerX[f] - kFingerW / 2).round();
    fill(x0, kTipY, x0 + kFingerW.round(), kKnuckleY,
        fingerColour[f] ?? kSkin);
  }
  return RgbaFrame(px, kW, kH);
}

/// MediaPipe-shaped landmarks for that hand, every finger shifted sideways by
/// [dx] px — the error the centring has to undo.
List<Offset> landmarks({double dx = 0}) {
  final p = List<Offset>.filled(21, const Offset(200, 480)); // 0 = wrist
  for (int f = 0; f < 5; f++) {
    final x = kFingerX[f] + dx;
    // MCP, PIP, DIP, TIP for each finger: indices 1..4, 5..8, ...
    final base = 1 + f * 4;
    p[base] = Offset(x, kKnuckleY.toDouble());
    p[base + 1] = Offset(x, 250);
    p[base + 2] = Offset(x, 170); // the joint below the tip
    p[base + 3] = Offset(x, kTipY + 15.0); // the tip
  }
  // The knuckles are what the skin colour is learned from; keep them on the
  // back of the hand whatever shift is being tested.
  for (final i in [5, 9, 13, 17]) {
    p[i] = Offset(p[i].dx - dx, p[i].dy);
  }
  return [for (final q in p) Offset(q.dx / kW, q.dy / kH)];
}

double tipX(CenteredHand h, int tip) => h.landmarks[tip].dx * kW;

const tips = [8, 12, 16, 20];
const fingerOf = {8: 1, 12: 2, 16: 3, 20: 4};

void main() {
  group('centring nails on the finger', () {
    for (final dx in const [-12.0, -6.0, 6.0, 12.0]) {
      test('a hand detected ${dx}px to one side is brought back', () {
        final r = centerOnFingers(hand(), landmarks(dx: dx));
        for (final t in tips) {
          expect(r.centeredTips, contains(t));
          expect(tipX(r, t), closeTo(kFingerX[fingerOf[t]!], 1.5),
              reason: 'tip $t');
        }
      });
    }

    test('control: landmarks already on the fingers are left where they are',
        () {
      final r = centerOnFingers(hand(), landmarks());
      for (final t in tips) {
        expect(tipX(r, t), closeTo(kFingerX[fingerOf[t]!], 1.0));
      }
    });

    test('a finger in shade is still found', () {
      // Darker than the back of the hand by more than the fixed skin cut,
      // but still far closer to skin than the table is — the shaded ring
      // finger on the 15 October photo.
      final r = centerOnFingers(
        hand(fingerColour: {3: [180, 148, 136]}),
        landmarks(dx: 10),
      );
      expect(r.centeredTips, contains(16));
      expect(tipX(r, 16), closeTo(kFingerX[3], 1.5));
    });

    test('never moves a nail toward the wrong finger', () {
      // Pushed up to exactly halfway between two fingers: the case where the
      // nearest skin could just as well be the neighbour. The property that
      // matters is "never worse": a nail is either left alone, or it ends up
      // nearer its OWN finger than it started AND nearer its own finger than
      // any other. (It may stop short of the centre: one correction is capped,
      // so an outer finger detected a full gap away is only partly brought
      // back — toward the right finger.)
      for (final dx in const [-30.0, 30.0, -25.0, 25.0, -18.0, 18.0]) {
        final input = landmarks(dx: dx);
        final r = centerOnFingers(hand(), input);
        for (final t in tips) {
          final own = kFingerX[fingerOf[t]!];
          final before = input[t].dx * kW;
          final got = tipX(r, t);
          if ((got - before).abs() < 0.01) continue; // left alone: fine
          final why = 'dx=$dx tip $t: $before -> $got, own finger at $own';
          expect((got - own).abs(), lessThan((before - own).abs()),
              reason: '$why (moved away from its own finger)');
          for (final other in kFingerX) {
            if (other == own) continue;
            expect((got - own).abs(), lessThan((got - other).abs()),
                reason: '$why (now nearer finger at $other)');
          }
        }
      }
    });

    test('with no contrast to measure, nothing is moved', () {
      // A background the colour of skin: there is no edge to find, so the
      // detector's positions must stand.
      final input = landmarks(dx: 10);
      final r = centerOnFingers(hand(background: kSkin), input);
      expect(r.centeredTips, isEmpty);
      for (int i = 0; i < 21; i++) {
        expect(r.landmarks[i], input[i]);
      }
    });

    test('the thumb is never moved', () {
      final input = landmarks(dx: 10);
      final r = centerOnFingers(hand(), input);
      expect(r.centeredTips, isNot(contains(4)));
      expect(r.landmarks[4], input[4]);
      expect(r.landmarks[3], input[3]);
    });
  });

  group('placement after centring', () {
    test('a centred ring and pinky skip the fixed inward pull', () {
      final lm = [
        for (final p in landmarks()) Offset(p.dx * kW, p.dy * kH),
      ];
      final pulled = computeNailPoses(lm);
      final centred = computeNailPoses(lm, centeredTips: {16, 20});
      // Upright fingers: without the pull, the nail sits exactly on the axis.
      expect(centred[3].center.dx, closeTo(kFingerX[3], 0.01));
      expect(centred[4].center.dx, closeTo(kFingerX[4], 0.01));
      // Control: with the pull they move off it, toward the middle finger.
      expect(pulled[3].center.dx, lessThan(kFingerX[3] - 1));
      expect(pulled[4].center.dx, lessThan(kFingerX[4] - 1));
      // Fingers that were not centred are placed exactly as before.
      for (final i in [0, 1, 2]) {
        expect(centred[i].center, pulled[i].center);
      }
    });
  });
}
