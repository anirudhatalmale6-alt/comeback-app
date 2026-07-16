import 'dart:math' as math;
import 'dart:ui';

/// The outcome of checking a live camera frame for the guided hand-capture.
/// [ready] means all conditions pass and the photo can be taken.
enum CaptureCheck {
  noHand,
  offCenter,
  tooFar,
  tooClose,
  fingersTogether,
  tooDark,
  tooBright,
  ready,
}

extension CaptureCheckMessage on CaptureCheck {
  /// User-facing guidance shown on the capture screen.
  String get message {
    switch (this) {
      case CaptureCheck.noHand:
        return 'Place your hand inside the outline';
      case CaptureCheck.offCenter:
        return 'Center your hand in the outline';
      case CaptureCheck.tooFar:
        return 'Move your hand closer';
      case CaptureCheck.tooClose:
        return 'Move your hand farther';
      case CaptureCheck.fingersTogether:
        return 'Please spread your fingers slightly';
      case CaptureCheck.tooDark:
        return 'Lighting is too dark';
      case CaptureCheck.tooBright:
        return 'Too much reflection';
      case CaptureCheck.ready:
        return 'Hold still…';
    }
  }

  bool get isReady => this == CaptureCheck.ready;
}

/// Tunable thresholds for the capture gate. Starting values; expected to be
/// refined from real-device tester feedback.
class CaptureThresholds {
  /// Hand bounding-box height as a fraction of the frame height.
  final double minHandHeightFrac; // below → too far
  final double maxHandHeightFrac; // above → too close
  /// How far the hand centre may be from the frame centre (fraction of frame).
  final double maxCenterOffsetFrac;
  /// Minimum gap between adjacent fingertips, as a fraction of hand width.
  final double minFingerGapFrac;
  /// Average frame brightness (0–255) bounds.
  final double minBrightness;
  /// Fraction of near-white (glare) pixels allowed.
  final double maxGlareFrac;

  const CaptureThresholds({
    this.minHandHeightFrac = 0.45,
    this.maxHandHeightFrac = 0.92,
    this.maxCenterOffsetFrac = 0.22,
    this.minFingerGapFrac = 0.11,
    this.minBrightness = 60,
    this.maxGlareFrac = 0.14,
  });
}

/// Fingertip landmark indices (thumb → pinky).
const List<int> kFingertips = [4, 8, 12, 16, 20];

/// Evaluates one frame. [landmarks] are image-pixel points (null if no hand).
/// [frameSize] is the analysed frame size. [brightness] is mean luma 0–255 and
/// [glareFrac] the fraction of near-white pixels, both precomputed by the
/// caller from the frame bytes.
CaptureCheck evaluateFrame({
  required List<Offset>? landmarks,
  required Size frameSize,
  required double brightness,
  required double glareFrac,
  CaptureThresholds t = const CaptureThresholds(),
}) {
  // Lighting first — cheap and applies even with no hand.
  if (brightness < t.minBrightness) return CaptureCheck.tooDark;
  if (glareFrac > t.maxGlareFrac) return CaptureCheck.tooBright;

  if (landmarks == null || landmarks.length < 21) return CaptureCheck.noHand;

  double minX = double.infinity, minY = double.infinity;
  double maxX = -double.infinity, maxY = -double.infinity;
  for (final p in landmarks) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  final handW = maxX - minX, handH = maxY - minY;
  final heightFrac = handH / frameSize.height;

  if (heightFrac < t.minHandHeightFrac) return CaptureCheck.tooFar;
  if (heightFrac > t.maxHandHeightFrac) return CaptureCheck.tooClose;

  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  final offX = (cx - frameSize.width / 2).abs() / frameSize.width;
  final offY = (cy - frameSize.height / 2).abs() / frameSize.height;
  if (offX > t.maxCenterOffsetFrac || offY > t.maxCenterOffsetFrac) {
    return CaptureCheck.offCenter;
  }

  // Finger spread: smallest gap between adjacent fingertips (index→pinky; the
  // thumb naturally sits apart so it is excluded from the gap test).
  double minGap = double.infinity;
  for (int i = 1; i < kFingertips.length - 1; i++) {
    final a = landmarks[kFingertips[i]];
    final b = landmarks[kFingertips[i + 1]];
    minGap = math.min(minGap, (a - b).distance);
  }
  if (handW > 0 && minGap / handW < t.minFingerGapFrac) {
    return CaptureCheck.fingersTogether;
  }

  return CaptureCheck.ready;
}
