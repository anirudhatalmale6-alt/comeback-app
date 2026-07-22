import 'dart:math' as math;
import 'dart:ui';

/// Turns a set of 21 MediaPipe hand landmarks into a nail placement for each
/// finger: where the nail sits, how big it is, and its angle. Pure geometry so
/// it can be unit-tested without a camera or device.
///
/// Landmark indexing follows MediaPipe Hands (0 = wrist, 4 = thumb tip, 8 =
/// index tip, ... 20 = pinky tip). All coordinates are in IMAGE pixels.
class NailPose {
  /// Centre of the nail, in image pixels.
  final Offset center;

  /// Rotation in radians for a nail sprite whose tip points UP at angle 0.
  /// Matches Flutter's Transform.rotate convention (y-down screen space).
  final double rotation;

  /// Nail length (tip → cuticle) and width, in image pixels.
  final double length;
  final double width;

  const NailPose({
    required this.center,
    required this.rotation,
    required this.length,
    required this.width,
  });
}

/// (fingertip index, joint-just-below index) for thumb → pinky.
const List<List<int>> kFingerJoints = [
  [4, 3],
  [8, 7],
  [12, 11],
  [16, 15],
  [20, 19],
];

/// How long the nail is relative to the tip→joint segment, and how wide it is
/// relative to its own length. Tuned on real hand photos; adjustable from
/// on-device tester feedback.
///
/// The real nail PLATE (cuticle → free edge) is a bit under half the distal
/// phalanx, and the tip→DIP-joint segment we measure IS that phalanx, so the
/// nail length is ~0.52 of it. Paired with the backset below the nail caps the
/// fingertip — it sits on the plate, not running down the finger past the
/// cuticle (which is what 0.58/0.68 did) and not overshooting into a long blob.
/// Verified by rendering the geometry onto a hand skeleton (placement_render_test).
/// Bumped 0.52→0.58, then 0.58→0.62 on tester feedback that the nails read too
/// small / didn't fill the real nail bed — this scales the whole auto-nail up.
/// 0.62 (with the wider aspect) then read "too big" — round blobs past the bed —
/// so trimmed 0.62→0.56 to bring the overall nail size back down.
const double kNailLengthFactor = 0.56;
const double kNailWidthFactor = 0.56;

/// How far back from the fingertip (as a fraction of nail length) the nail
/// centre sits. This is deliberately LOW (0.16) so the nail rides up and caps
/// the fingertip. On-device the MediaPipe tip landmark maps well SHORT of the
/// visible fingertip (confirmed across tester shots: at backset 0.50 and even
/// 0.35 the nails still read low, sitting under the real nail), so the anatomical
/// ~0.50 value leaves a gap above every nail. Pushing the free-edge forward
/// closes that gap and lands the nail on top of the natural nail. If a future
/// build fixes the landmark mapping this can climb back toward 0.35. (Higher
/// values pull the nail short / down the finger.) Lowered 0.16→0.10 on tester
/// feedback ("move all the nails up so you can't see the real nails"). Nudged
/// 0.10→0.13 after the BIGGER nails floated above the tips, but once the nails
/// were shrunk (v1.6.54) 0.13 read LOW again — bare fingertip above each nail,
/// "doesn't cover the full nail". Smaller nails need LESS backset to reach the
/// visible tip, so 0.13→0.08 to ride them back up over the whole nail bed.
const double kNailBacksetFactor = 0.08;

/// The pinky gets its own backset. Its tip→DIP segment is the shortest of the
/// five, so MediaPipe landmark noise is a bigger FRACTION of it and the pinky
/// tip maps shortest — the pinky nail reads low. A lower backset pushes it up.
/// Was 0.06, which over-projected it forward along the pinky's diagonal axis and
/// threw the nail sideways; the lateral term (below) handles the sideways drift
/// directly. Lowered 0.10→0.04 with the global up-shift so the pinky rises too.
/// Nudged 0.04→0.01 with the v1.6.55 up-shift (pinky still read low/short).
const double kNailPinkyBacksetFactor = 0.01;

/// The thumb reads consistently LOW on the tester's device (its axis is diagonal
/// and its distal phalanx is stubby, so the tip landmark lands well short of the
/// real nail bed). A NEGATIVE backset pushes the thumb nail past the tip
/// landmark, up onto the nail bed where it belongs (0.04 still read low across
/// tester shots; -0.06 lifted it onto the bed, -0.10 with the global up-shift).
const double kNailThumbBacksetFactor = -0.10;

/// Tip landmark indices (MediaPipe Hands).
const int kThumbTipIndex = 4;
const int kMiddleTipIndex = 12;
const int kRingTipIndex = 16;
const int kPinkyTipIndex = 20;

/// Outer-finger tips (ring, pinky) are detected slightly OUTWARD of the true
/// nail on this device, so the nail drifts away from the hand's midline. We pull
/// each outer nail back toward its neighbouring INNER finger by a fraction of
/// nail width. Direction is taken from the neighbour landmark (ring→middle,
/// pinky→ring), so it is orientation-independent — it works for either hand and
/// any photo rotation without needing to know screen left/right. The pinky drifts
/// more than the ring, hence the larger factor.
const Map<int, int> kLateralNeighborTip = {
  kRingTipIndex: kMiddleTipIndex,
  kPinkyTipIndex: kRingTipIndex,
};
const Map<int, double> kLateralInwardFactor = {
  kRingTipIndex: 0.18,
  kPinkyTipIndex: 0.32,
};

/// Rotates a NORMALIZED point (each coord 0–1) within the unit square by
/// [quarterTurnsCw] * 90° clockwise. Used to convert landmarks from the camera
/// sensor's orientation to the upright, saved-photo orientation (back camera,
/// no mirroring). Any device-specific flip is a one-line change here.
Offset rotateNormalized(Offset p, int quarterTurnsCw) {
  final q = ((quarterTurnsCw % 4) + 4) % 4;
  switch (q) {
    case 1: // 90° CW
      return Offset(1 - p.dy, p.dx);
    case 2: // 180°
      return Offset(1 - p.dx, 1 - p.dy);
    case 3: // 270° CW
      return Offset(p.dy, 1 - p.dx);
    default:
      return p;
  }
}

/// Computes a [NailPose] per finger from [landmarks] (21 image-pixel points).
/// Fingers whose joints are degenerate (too close) are skipped.
List<NailPose> computeNailPoses(List<Offset> landmarks) {
  assert(landmarks.length >= 21, 'expected 21 hand landmarks');
  final poses = <NailPose>[];
  for (final fj in kFingerJoints) {
    final tip = landmarks[fj[0]];
    final joint = landmarks[fj[1]];
    final dx = tip.dx - joint.dx;
    final dy = tip.dy - joint.dy;
    final seg = math.sqrt(dx * dx + dy * dy);
    if (seg < 3) continue;
    final dirX = dx / seg, dirY = dy / seg;

    final length = seg * kNailLengthFactor;
    final width = length * kNailWidthFactor;

    // Rotation so a tip-up sprite aligns its tip along (dirX, dirY).
    // Rotating (0,-1) by θ gives (sinθ, -cosθ); solve for dir → θ.
    final rotation = math.atan2(dirX, -dirY);

    double backset = kNailBacksetFactor;
    if (fj[0] == kThumbTipIndex) {
      backset = kNailThumbBacksetFactor;
    } else if (fj[0] == kPinkyTipIndex) {
      backset = kNailPinkyBacksetFactor;
    }
    var center = Offset(
      tip.dx - dirX * (length * backset),
      tip.dy - dirY * (length * backset),
    );

    // Pull outer-finger (ring/pinky) nails inward toward their neighbour to
    // undo MediaPipe's outward tip bias. Perpendicular-agnostic: we simply move
    // a fraction of the nail width along the direction to the neighbour tip.
    final neighborIdx = kLateralNeighborTip[fj[0]];
    if (neighborIdx != null && neighborIdx < landmarks.length) {
      final nb = landmarks[neighborIdx];
      final lx = nb.dx - tip.dx, ly = nb.dy - tip.dy;
      final ln = math.sqrt(lx * lx + ly * ly);
      if (ln > 1e-3) {
        final f = kLateralInwardFactor[fj[0]]!;
        center = Offset(
          center.dx + (lx / ln) * width * f,
          center.dy + (ly / ln) * width * f,
        );
      }
    }
    poses.add(NailPose(
      center: center,
      rotation: rotation,
      length: length,
      width: width,
    ));
  }
  return poses;
}

/// The rectangle a [BoxFit.contain] image occupies inside a [box], plus the
/// scale from image pixels to box pixels. Used to map nail poses computed in
/// image space onto the on-screen editor which shows the photo letter-boxed.
class FitTransform {
  final double scale;
  final Offset offset; // top-left of the fitted image within the box
  const FitTransform(this.scale, this.offset);

  Offset imageToBox(Offset p) => offset + p * scale;

  static FitTransform contain(Size imageSize, Size box) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return const FitTransform(1, Offset.zero);
    }
    final s = math.min(box.width / imageSize.width, box.height / imageSize.height);
    final dw = imageSize.width * s, dh = imageSize.height * s;
    return FitTransform(s, Offset((box.width - dw) / 2, (box.height - dh) / 2));
  }
}
