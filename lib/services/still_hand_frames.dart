import 'dart:typed_data';
import 'dart:ui';

/// The pure, testable half of finding a hand in a still photo.
///
/// Until v1.7.1 only the guided camera ("Auto Try-On") ran hand detection.
/// Every other way of getting a photo into the editor — Take a Photo, Upload,
/// Change photo — went straight to a fixed, generic fan of nails that cannot
/// follow anybody's actual fingers. That is what "the nails are not auto
/// adjusting to the person's nails" was.
///
/// The detector the app ships (MediaPipe, via `hand_landmarker`) only takes
/// camera frames, as YUV planes, so a still photo has to be presented to it as
/// one. This file holds everything about that which does not need a device:
/// the framing passes, the RGB→YUV conversion, and mapping the answer back.
/// The platform half is `still_hand_detector.dart`.

/// A raw RGBA image, 4 bytes per pixel, row-major, no padding.
class RgbaFrame {
  final Uint8List rgba;
  final int width;
  final int height;
  const RgbaFrame(this.rgba, this.width, this.height);
}

/// One framing of the photo to try. Either a crop (a window of the photo, in
/// 0..1 coordinates) or a pad (a black margin added all round, as a fraction
/// of the longer side).
class DetectPass {
  final String name;
  final Rect? crop;
  final double pad;
  const DetectPass.crop(this.name, Rect window)
      : crop = window,
        pad = 0;
  const DetectPass.pad(this.name, this.pad) : crop = null;
}

/// The framings tried, in order, until one finds a hand.
///
/// MediaPipe finds a hand in two stages: a palm detector looks at the whole
/// frame shrunk to a small square, then a landmark model works on the hand it
/// found. On a busy photo the first stage can miss a hand that is plainly
/// there — on Ashlyn's 14 October photo it found nothing at its normal
/// confidence, while a closer crop of the same photo found the hand at 0.94.
///
/// So the whole frame goes first (it is the right answer for a normal photo
/// and nothing below ever runs for those), then a padded copy, which suits a
/// hand that fills or runs off the frame, then progressively closer crops.
///
/// What was actually measured, offline, with the model the app ships: on her
/// 14 October photo the whole frame finds nothing at normal confidence and the
/// padded pass finds the hand. Most of the other images she has sent are chat
/// screenshots or photos of phones rather than spread-hand photos, so they say
/// little about real uploads — but they did confirm that a hand found by a
/// crop or pad pass maps back onto the right fingers. And because the whole
/// frame always goes first, no photo that is fitted today is fitted any
/// differently.
const List<DetectPass> kStillDetectPasses = [
  DetectPass.crop('full', Rect.fromLTRB(0, 0, 1, 1)),
  DetectPass.pad('pad25', 0.25),
  DetectPass.crop('c85', Rect.fromLTRB(0.075, 0.075, 0.925, 0.925)),
  DetectPass.crop('c70', Rect.fromLTRB(0.15, 0.15, 0.85, 0.85)),
  DetectPass.crop('top80', Rect.fromLTRB(0.05, 0.0, 0.95, 0.80)),
  DetectPass.crop('mid', Rect.fromLTRB(0.12, 0.15, 0.88, 0.90)),
];

/// The photo is shrunk to at most this on its longer side before detection.
/// MediaPipe works on a much smaller square internally, and landmarks come back
/// normalised, so a bigger input only costs time.
const int kStillDetectMaxSide = 960;

/// The pixel rectangle [pass] covers in a [w]×[h] frame, for a crop pass.
({int x0, int y0, int x1, int y1}) cropBox(DetectPass pass, int w, int h) {
  final c = pass.crop!;
  return (
    x0: (c.left * w).round().clamp(0, w),
    y0: (c.top * h).round().clamp(0, h),
    x1: (c.right * w).round().clamp(0, w),
    y1: (c.bottom * h).round().clamp(0, h),
  );
}

/// The margin, in pixels, a pad pass adds on every side of a [w]×[h] frame.
int padMargin(DetectPass pass, int w, int h) =>
    ((w > h ? w : h) * pass.pad).round();

/// The frame the detector should see for [pass].
RgbaFrame framePass(RgbaFrame src, DetectPass pass) {
  if (pass.crop != null) {
    final b = cropBox(pass, src.width, src.height);
    final cw = b.x1 - b.x0, ch = b.y1 - b.y0;
    final out = Uint8List(cw * ch * 4);
    for (int y = 0; y < ch; y++) {
      final from = ((b.y0 + y) * src.width + b.x0) * 4;
      out.setRange(y * cw * 4, (y + 1) * cw * 4, src.rgba, from);
    }
    return RgbaFrame(out, cw, ch);
  }
  final m = padMargin(pass, src.width, src.height);
  final pw = src.width + 2 * m, ph = src.height + 2 * m;
  final out = Uint8List(pw * ph * 4);
  // Opaque black margin. Uint8List starts zeroed, so only alpha needs setting.
  for (int i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  for (int y = 0; y < src.height; y++) {
    final to = ((m + y) * pw + m) * 4;
    out.setRange(to, to + src.width * 4, src.rgba, y * src.width * 4);
  }
  return RgbaFrame(out, pw, ph);
}

/// Maps landmarks the detector returned for [pass] (normalised to the frame it
/// was shown) back to normalised coordinates of the whole photo.
List<Offset> passToPhoto(
    List<Offset> lm, DetectPass pass, int photoW, int photoH) {
  if (pass.crop != null) {
    final b = cropBox(pass, photoW, photoH);
    final cw = b.x1 - b.x0, ch = b.y1 - b.y0;
    return [
      for (final p in lm)
        Offset((b.x0 + p.dx * cw) / photoW, (b.y0 + p.dy * ch) / photoH),
    ];
  }
  final m = padMargin(pass, photoW, photoH);
  final pw = photoW + 2 * m, ph = photoH + 2 * m;
  return [
    for (final p in lm)
      Offset((p.dx * pw - m) / photoW, (p.dy * ph - m) / photoH),
  ];
}

/// Index of the hand with the largest landmark bounding box — the hand the
/// photo is of, rather than one at the edge of the frame. -1 if none.
int largestHand(List<List<Offset>> hands) {
  int best = -1;
  double bestArea = -1;
  for (int i = 0; i < hands.length; i++) {
    final h = hands[i];
    if (h.length < 21) continue;
    double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (final p in h) {
      if (p.dx < x0) x0 = p.dx;
      if (p.dx > x1) x1 = p.dx;
      if (p.dy < y0) y0 = p.dy;
      if (p.dy > y1) y1 = p.dy;
    }
    final a = (x1 - x0) * (y1 - y0);
    if (a > bestArea) {
      bestArea = a;
      best = i;
    }
  }
  return best;
}

/// Three YUV 4:2:0 planes, laid out the way the detector reads them: Y at full
/// size with a row stride of [width]; U and V at half size with a row stride of
/// [width] / 2 and a pixel stride of 1.
class I420Frame {
  final Uint8List y, u, v;
  final int width, height;
  const I420Frame(this.y, this.u, this.v, this.width, this.height);
}

/// Converts [src] to the YUV the detector expects.
///
/// It has to be the inverse of the plugin's own decoder
/// (`MyHandLandmarker.yuvToRgbBitmap`), which is BT.601 *limited* range — it
/// subtracts 16 from Y and scales by 1.164. Full-range YUV would come out of
/// that decoder washed out and low-contrast. Width and height are trimmed to
/// even numbers because chroma is shared by 2×2 blocks.
I420Frame rgbaToI420(RgbaFrame src) {
  final w = src.width & ~1, h = src.height & ~1;
  final s = src.rgba, sw = src.width;
  final y = Uint8List(w * h);
  final cw = w >> 1, ch = h >> 1;
  final u = Uint8List(cw * ch), v = Uint8List(cw * ch);

  int clamp(int x) => x < 0 ? 0 : (x > 255 ? 255 : x);

  for (int j = 0; j < h; j++) {
    final row = j * sw * 4;
    final yRow = j * w;
    for (int i = 0; i < w; i++) {
      final o = row + i * 4;
      final r = s[o], g = s[o + 1], b = s[o + 2];
      y[yRow + i] = clamp(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
    }
  }
  for (int j = 0; j < ch; j++) {
    for (int i = 0; i < cw; i++) {
      final o00 = ((2 * j) * sw + 2 * i) * 4;
      final o10 = o00 + 4;
      final o01 = o00 + sw * 4;
      final o11 = o01 + 4;
      final r = (s[o00] + s[o10] + s[o01] + s[o11] + 2) >> 2;
      final g = (s[o00 + 1] + s[o10 + 1] + s[o01 + 1] + s[o11 + 1] + 2) >> 2;
      final b = (s[o00 + 2] + s[o10 + 2] + s[o01 + 2] + s[o11 + 2] + 2) >> 2;
      u[j * cw + i] = clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
      v[j * cw + i] = clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
    }
  }
  return I420Frame(y, u, v, w, h);
}
