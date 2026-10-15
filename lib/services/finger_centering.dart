import 'dart:math' as math;
import 'dart:ui';

import 'still_hand_frames.dart';

/// Moves each nail sideways onto the middle of the finger it belongs to, by
/// measuring that finger's edges in the photo itself.
///
/// Why this exists. The hand detector gives one point per joint, and those
/// points can land a little to one side of the real finger — on Ashlyn's
/// 15 October photo every nail sat right of its finger, the middle one by a
/// full half-finger. Some of that is the detector, and some is physical: the
/// detector marks the finger's bones, the nail sits on its top surface, and a
/// hand photographed slightly from one side shows the two apart. Which way it
/// leans depends on the photo.
///
/// That is why the old fix — a fixed inward pull on the ring and pinky — never
/// settled: a constant that suits one photo moves the next one the wrong way
/// (an earlier complaint was "too far left"). A measurement taken from the
/// photo cannot have that problem.
///
/// How. Along each finger, on the skin between the cuticle and the first
/// knuckle (below the nail, so painted nails or real polish do not matter),
/// several short lines are cut across the finger. On each, the pixels that
/// look like this hand's skin are found and the run of them nearest the
/// finger's axis is taken to be the finger. The middle of that run, against
/// the axis, is how far the nail should move.
///
/// The rule it is built around is: never make a nail worse than leaving it
/// alone. So it only moves a nail when the lines agree with one another, the
/// width they find is a believable finger, and the move stays well inside the
/// finger; a line may never cross halfway to the next finger, so a nail cannot
/// be moved onto its neighbour. Otherwise the nail stays where it was.
///
/// The thumb is left alone. It is short, foreshortened and angled, and a
/// sideways offset measured down near its joint does not hold up at the nail —
/// on her photo it pushed the thumb off its edge.
///
/// Pure Dart on a small RGBA copy of the photo, so it is tested without a
/// device and costs a few thousand pixel reads.

/// The result: landmarks with corrected fingers moved sideways, and which
/// fingertips (MediaPipe tip indices) were corrected.
class CenteredHand {
  final List<Offset> landmarks;
  final Set<int> centeredTips;
  const CenteredHand(this.landmarks, this.centeredTips);
}

// (tip, joint below) for the fingers that are corrected, index → pinky, in
// order across the hand so each has known neighbours.
const List<List<int>> _kCorrected = [
  [8, 7],
  [12, 11],
  [16, 15],
  [20, 19],
];
// The thumb takes part only as a neighbour that bounds the index's search.
const List<int> _kThumb = [4, 3];

/// Where along the finger the lines are cut, as a fraction of the way from
/// the tip to the joint below it: below the nail, above the knuckle.
const List<double> kCenteringStations = [0.60, 0.70, 0.80, 0.90];

/// Colour distance below which a pixel counts as skin, before the per-line
/// adjustment for shade (see [_skinRuns]).
const double kSkinDistance = 42;

/// [norm] is 21 landmarks normalised to [frame]. Returns them with each finger
/// that could be measured confidently moved sideways onto its silhouette.
CenteredHand centerOnFingers(RgbaFrame frame, List<Offset> norm) {
  if (norm.length < 21) return CenteredHand(norm, const {});
  final w = frame.width.toDouble(), h = frame.height.toDouble();
  final pts = [for (final p in norm) Offset(p.dx * w, p.dy * h)];

  final ref = _skinReference(frame, pts);
  if (ref == null) return CenteredHand(norm, const {});

  final out = List<Offset>.of(pts);
  final centered = <int>{};
  final across = <List<int>>[_kThumb, ..._kCorrected];

  for (int k = 1; k < across.length; k++) {
    final tip = across[k][0], joint = across[k][1];
    final t = pts[tip], d = pts[joint];
    final seg = (t - d).distance;
    if (seg < 8) continue;
    final u = (t - d) / seg;
    final perp = Offset(-u.dy, u.dx);

    final offs = <double>[], widths = <double>[];
    for (final s in kCenteringStations) {
      final c = t + (d - t) * s;

      // How far a finger may be judged to sit from this axis: halfway to the
      // axis of the finger on either side.
      double lo = -0.9 * seg, hi = 0.9 * seg;
      for (final nb in [k - 1, k + 1]) {
        if (nb < 0 || nb >= across.length) continue;
        final nt = pts[across[nb][0]], nj = pts[across[nb][1]];
        final cn = nt + (nj - nt) * s;
        final tn = _dot(cn - c, perp);
        if (tn > 0) hi = math.min(hi, tn / 2);
        if (tn < 0) lo = math.max(lo, tn / 2);
      }

      final runs = _skinRuns(frame, c, perp, (1.3 * seg).round(), ref);
      final ok = <(double, double)>[];
      for (final r in runs) {
        // The run's CENTRE must be nearer this finger's axis than a
        // neighbour's — the run itself may reach past the halfway line, or a
        // shift of more than half the gap between fingers could never be
        // corrected. A neighbour cannot pass this test, and two touching
        // fingers merged into one run fail the width test below.
        final mid = (r.$1 + r.$2) / 2;
        // And a dead zone: a finger judged to sit in the outer fifth before
        // the halfway line is too close to call. Without it, a hand detected
        // exactly between two fingers was decided by half-pixel rounding —
        // and the test caught it choosing the neighbour.
        if (mid <= 0.8 * lo || mid >= 0.8 * hi) continue;
        final width = r.$2 - r.$1;
        if (width < 0.40 * seg || width > 1.05 * seg) continue;
        ok.add(r);
      }
      if (ok.isEmpty) continue;
      (double, double)? pick;
      for (final r in ok) {
        if (r.$1 <= 0 && 0 <= r.$2) pick = r;
      }
      pick ??= ok.reduce((x, y) =>
          ((x.$1 + x.$2) / 2).abs() <= ((y.$1 + y.$2) / 2).abs() ? x : y);
      final mid = (pick.$1 + pick.$2) / 2;
      if (mid.abs() > 0.6 * seg) continue;
      offs.add(mid);
      widths.add(pick.$2 - pick.$1);
    }

    if (offs.length < 2) continue;
    final wMed = _median(widths);
    final spread = offs.reduce(math.max) - offs.reduce(math.min);
    if (spread >= 0.25 * wMed) continue; // the lines disagree: leave it
    final off = _median(offs).clamp(-0.55 * wMed, 0.55 * wMed);
    final shift = perp * off;
    out[tip] = pts[tip] + shift;
    out[joint] = pts[joint] + shift;
    centered.add(tip);
  }

  return CenteredHand(
    [for (final p in out) Offset(p.dx / w, p.dy / h)],
    centered,
  );
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

double _median(List<double> v) {
  final s = List<double>.of(v)..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

List<int>? _pixel(RgbaFrame f, Offset p) {
  final x = p.dx.round(), y = p.dy.round();
  if (x < 0 || y < 0 || x >= f.width || y >= f.height) return null;
  final o = (y * f.width + x) * 4;
  return [f.rgba[o], f.rgba[o + 1], f.rgba[o + 2]];
}

double _colourDistance(List<int> a, List<double> b) {
  final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// This hand's skin colour, taken from the back of the hand between the
/// knuckles rather than from a finger, because the point being corrected may
/// itself be off the finger.
List<double>? _skinReference(RgbaFrame f, List<Offset> pts) {
  final wrist = pts[0];
  final knuckles = [pts[5], pts[9], pts[13], pts[17]];
  final r = <int>[], g = <int>[], b = <int>[];
  for (int i = 0; i < 3; i++) {
    final a = knuckles[i], c = knuckles[i + 1];
    for (int s = 0; s < 7; s++) {
      final q = a + (c - a) * (0.2 + 0.1 * s);
      for (final k in const [0.08, 0.18]) {
        final px = _pixel(f, q + (wrist - q) * k);
        if (px == null) continue;
        r.add(px[0]);
        g.add(px[1]);
        b.add(px[2]);
      }
    }
  }
  if (r.length < 5) return null;
  double med(List<int> v) => _median([for (final x in v) x.toDouble()]);
  return [med(r), med(g), med(b)];
}

/// Runs of skin along the line through [c] in direction [perp], as offsets
/// (start, end) from [c].
///
/// The cut between skin and not-skin is set per line: lighting changes along
/// a hand, and a finger in shade can sit well away from the back-of-hand
/// colour while still being far closer to it than the background is. On her
/// photo the shaded ring finger read 40–76 away from the reference and the
/// table 200–280, so a fixed cut of 42 lost the finger entirely. The cut goes
/// halfway between the two levels seen on the line.
List<(double, double)> _skinRuns(
    RgbaFrame f, Offset c, Offset perp, int half, List<double> ref) {
  final n = 2 * half + 1;
  final d = List<double>.filled(n, double.infinity);
  final finite = <double>[];
  for (int i = 0; i < n; i++) {
    final px = _pixel(f, c + perp * (i - half).toDouble());
    if (px == null) continue;
    d[i] = _colourDistance(px, ref);
    finite.add(d[i]);
  }
  if (finite.isEmpty) return const [];
  finite.sort();
  final p10 = finite[((finite.length - 1) * 0.1).round()];
  final p90 = finite[((finite.length - 1) * 0.9).round()];
  // Halfway between the skin level and the background level on this line.
  final tau = math.max(kSkinDistance, (p10 + p90) / 2);

  final skin = [for (final v in d) v < tau];
  // Close gaps of up to 2 px — creases and glints are not the finger's edge.
  for (int i = 1; i < n - 2; i++) {
    if (!skin[i] && skin[i - 1] && (skin[i + 1] || skin[i + 2])) skin[i] = true;
  }
  final runs = <(double, double)>[];
  int? start;
  for (int i = 0; i < n; i++) {
    if (skin[i] && start == null) start = i;
    final last = i == n - 1;
    if (start != null && (!skin[i] || last)) {
      final end = skin[i] && last ? i : i - 1;
      runs.add(((start - half).toDouble(), (end - half).toDouble()));
      start = null;
    }
  }
  return runs;
}
