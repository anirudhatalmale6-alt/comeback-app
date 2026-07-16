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
const double kNailLengthFactor = 0.92;
const double kNailWidthFactor = 0.60;

/// How far back from the fingertip (as a fraction of nail length) the nail
/// centre sits, so the nail tip lands near the fingertip.
const double kNailBacksetFactor = 0.26;

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

    final center = Offset(
      tip.dx - dirX * (length * kNailBacksetFactor),
      tip.dy - dirY * (length * kNailBacksetFactor),
    );
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
