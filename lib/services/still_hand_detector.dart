import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraImageData, CameraImageFormat, CameraImagePlane;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'still_hand_frames.dart';

/// Finds the hand in a still photo, so a photo the customer takes or uploads
/// is fitted automatically the same way the guided camera already is.
///
/// It uses the SAME detector as the guided camera — the MediaPipe model inside
/// `hand_landmarker` — fed one still frame. Two things about that package
/// shaped how this is written, and both are worth knowing before changing it:
///
/// * Its synchronous `detectFromYuv` does not work as shipped. It sets the
///   detector up in LIVE_STREAM mode and then calls `detect()`, which MediaPipe
///   only allows in IMAGE mode. So this goes through the asynchronous
///   `processFrame` path instead — the one the guided camera uses, and the one
///   already proven on Ashlyn's phone — and waits for the answer to arrive on
///   the result stream.
///
/// * That result stream is a single platform channel shared with the guided
///   camera, and a channel only has one active listener at a time: whoever
///   listens last takes it over, and whoever cancels switches it off for
///   everyone. So this listens ONLY while a detection is in progress and
///   cancels the moment it has an answer. A detector that sat listening for
///   the life of the screen would quietly break Auto Try-On.
///
/// One instance is kept per Try-On screen and disposed with it. The package
/// gives no way to close the native model, so creating one per photo would
/// leak a copy every time the customer changed photo.
///
/// Android only, like the guided camera. Elsewhere [detect] returns null and
/// the editor falls back to the manual starter set, exactly as before.
class StillHandDetector {
  HandLandmarkerPlugin? _plugin;
  bool _disposed = false;

  static bool get supported => Platform.isAndroid;

  /// Returns 21 landmarks normalised (0–1) to [photo] exactly as the editor
  /// displays it, or null if no hand was found or detection is unavailable.
  ///
  /// [photo] must be the decoded image the editor is showing: Flutter's decoder
  /// has already applied the photo's EXIF orientation to it, so landmarks
  /// found on it line up with what is on screen without any rotation here.
  Future<List<Offset>?> detect(ui.Image photo) async {
    if (!supported || _disposed) return null;
    StreamSubscription<List<Hand>>? sub;
    try {
      final frame = await _shrink(photo);
      _plugin ??= HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
        // CPU: one frame, so speed does not matter, and it is the delegate the
        // passes were checked against offline. GPU set-up also fails on some
        // phones where CPU does not.
        delegate: HandLandmarkerDelegate.cpu,
      );

      Completer<List<Hand>?>? waiting;
      sub = _plugin!.landmarkStream.listen((hands) {
        final c = waiting;
        waiting = null;
        if (c != null && !c.isCompleted) c.complete(hands);
      }, onError: (_) {});
      // The native side only starts forwarding results once our listen has
      // reached it, which happens asynchronously. A frame sent before then
      // would be answered into the void.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      for (final pass in kStillDetectPasses) {
        if (_disposed) return null;
        final yuv = await compute(rgbaToI420, framePass(frame, pass));

        List<Hand>? hands;
        // A live-stream detector may drop a frame it is too busy to take, and
        // a dropped frame produces no answer at all, not an empty one. Send it
        // twice before deciding the detector is not answering.
        for (int attempt = 0; attempt < 2 && hands == null; attempt++) {
          final c = Completer<List<Hand>?>();
          waiting = c;
          _plugin!.processFrame(_asCameraImage(yuv), 0);
          hands = await c.future.timeout(
            const Duration(milliseconds: 2500),
            onTimeout: () => null,
          );
        }
        // No answer twice running means the channel is not delivering, not
        // that there is no hand. Further framings would only time out too.
        if (hands == null) return null;

        final found = [
          for (final h in hands)
            [for (final l in h.landmarks) Offset(l.x, l.y)],
        ];
        final best = largestHand(found);
        if (best >= 0) {
          return passToPhoto(found[best], pass, frame.width, frame.height);
        }
      }
      return null;
    } catch (e) {
      debugPrint('StillHandDetector: $e');
      return null;
    } finally {
      await sub?.cancel();
    }
  }

  void dispose() {
    _disposed = true;
    _plugin?.dispose();
    _plugin = null;
  }

  /// Draws [img] at no more than [kStillDetectMaxSide] on its longer side and
  /// reads the pixels back. Scaled uniformly, so normalised landmarks found on
  /// the small copy are equally true of the full photo.
  static Future<RgbaFrame> _shrink(ui.Image img) async {
    final s = math.min(
        1.0, kStillDetectMaxSide / math.max(img.width, img.height));
    final w = math.max(2, (img.width * s).round());
    final h = math.max(2, (img.height * s).round());
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = FilterQuality.medium,
    );
    final small = await rec.endRecording().toImage(w, h);
    try {
      final bytes = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      return RgbaFrame(bytes!.buffer.asUint8List(), w, h);
    } finally {
      small.dispose();
    }
  }

  /// Presents an I420 frame as the camera frame the plugin expects.
  /// Format 35 is Android's YUV_420_888, which is what the guided camera feeds
  /// it; the plugin reads Y, then U and V with the strides given here.
  static CameraImage _asCameraImage(I420Frame f) {
    final cw = f.width ~/ 2, ch = f.height ~/ 2;
    return CameraImage.fromPlatformInterface(CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
      width: f.width,
      height: f.height,
      planes: [
        CameraImagePlane(
            bytes: f.y,
            bytesPerRow: f.width,
            bytesPerPixel: 1,
            width: f.width,
            height: f.height),
        CameraImagePlane(
            bytes: f.u, bytesPerRow: cw, bytesPerPixel: 1, width: cw, height: ch),
        CameraImagePlane(
            bytes: f.v, bytesPerRow: cw, bytesPerPixel: 1, width: cw, height: ch),
      ],
    ));
  }
}
