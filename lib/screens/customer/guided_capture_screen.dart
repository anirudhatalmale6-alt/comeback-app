import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'package:comeback_app/services/capture_conditions.dart';
import 'package:comeback_app/services/hand_geometry.dart';
import 'package:comeback_app/services/image_stats.dart';
import 'package:comeback_app/services/yuv_to_image.dart';

/// What the guided capture hands back: the photo it took plus the 21 hand
/// landmarks in the upright photo's NORMALIZED space (0–1), ready to drive
/// automatic nail placement.
class GuidedCaptureResult {
  final File imageFile;
  final List<Offset> normalizedLandmarks;
  const GuidedCaptureResult(this.imageFile, this.normalizedLandmarks);
}

/// Live camera screen that guides the user to a standardized, top-down hand
/// photo and auto-captures once framing, distance, finger spread and lighting
/// are all good and the hand holds still. Android only (uses MediaPipe hand
/// detection). If detection ever misbehaves, the resulting photo still flows
/// into the normal editor where nails can be adjusted by hand.
class GuidedCaptureScreen extends StatefulWidget {
  const GuidedCaptureScreen({super.key});

  @override
  State<GuidedCaptureScreen> createState() => _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends State<GuidedCaptureScreen> {
  CameraController? _cam;
  HandLandmarkerPlugin? _hlm;
  StreamSubscription<List<Hand>>? _sub;

  bool _ready = false;
  bool _capturing = false;
  String? _error;

  CaptureCheck _status = CaptureCheck.noHand;
  LumaStats _luma = const LumaStats(0, 0);
  int _sensorOrientation = 0;

  DateTime? _steadySince;
  Offset? _steadyCentroid;

  /// The most recent camera frame — the same stream of frames hand detection
  /// runs on. We turn THIS into the photo so the landmarks line up with it,
  /// instead of shooting a separate still that can have a different field of
  /// view or catch the hand a few milliseconds later (which made placement
  /// "sometimes completely off").
  CameraImage? _lastImage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _sensorOrientation = back.sensorOrientation;
      final cam = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _hlm = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.5,
      );
      await cam.initialize();
      _cam = cam;
      _sub = _hlm!.landmarkStream.listen(_onHands);
      await cam.startImageStream(_onFrame);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onFrame(CameraImage image) {
    if (_capturing) return;
    _lastImage = image;
    final p0 = image.planes.first;
    _luma = computeLumaStats(
        p0.bytes, image.width, image.height, p0.bytesPerRow);
    _hlm?.processFrame(image, _sensorOrientation);
  }

  void _onHands(List<Hand> hands) {
    if (_capturing || !mounted) return;
    final turns = _sensorOrientation ~/ 90;
    List<Offset>? upright;
    if (hands.isNotEmpty && hands.first.landmarks.length >= 21) {
      upright = hands.first.landmarks
          .map((l) => rotateNormalized(Offset(l.x, l.y), turns))
          .toList();
    }

    final status = evaluateFrame(
      landmarks: upright,
      frameSize: const Size(1, 1), // landmarks are already normalized
      brightness: _luma.brightness,
      glareFrac: _luma.glareFrac,
    );

    if (status.isReady && upright != null) {
      final c = _centroid(upright);
      if (_steadyCentroid == null ||
          (c - _steadyCentroid!).distance > 0.03) {
        _steadyCentroid = c;
        _steadySince = DateTime.now();
      } else if (_steadySince != null &&
          DateTime.now().difference(_steadySince!).inMilliseconds > 900) {
        _autoCapture(upright);
      }
    } else {
      _steadySince = null;
      _steadyCentroid = null;
    }
    setState(() => _status = status);
  }

  Offset _centroid(List<Offset> pts) {
    double x = 0, y = 0;
    for (final p in pts) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  Future<void> _autoCapture(List<Offset> landmarks) async {
    if (_capturing) return;
    _capturing = true;
    final frame = _lastImage;
    setState(() {});
    try {
      await _cam!.stopImageStream();
      // Preferred path: save the exact detection frame as the photo so the
      // landmarks map onto it perfectly. Falls back to a normal still if the
      // frame can't be converted, so capture can never be worse than before.
      File? file = await _saveDetectionFrame(frame);
      file ??= File((await _cam!.takePicture()).path);
      if (!mounted) return;
      Navigator.pop(context, GuidedCaptureResult(file, landmarks));
    } catch (e) {
      _capturing = false;
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Converts [image] (the frame detection ran on) to an upright JPEG on a
  /// background isolate and writes it to a temp file. Returns null if the frame
  /// is missing or not in the expected YUV420 layout, so the caller can fall
  /// back to a regular still.
  Future<File?> _saveDetectionFrame(CameraImage? image) async {
    if (image == null || image.planes.length < 3) return null;
    try {
      final y = image.planes[0];
      final u = image.planes[1];
      final v = image.planes[2];
      final frame = YuvFrame(
        y: Uint8List.fromList(y.bytes),
        u: Uint8List.fromList(u.bytes),
        v: Uint8List.fromList(v.bytes),
        width: image.width,
        height: image.height,
        yRowStride: y.bytesPerRow,
        uvRowStride: u.bytesPerRow,
        uvPixelStride: u.bytesPerPixel ?? 1,
        rotationTurns: _sensorOrientation ~/ 90,
      );
      final jpg = await compute(encodeYuvFrameToJpg, frame);
      final path =
          '${Directory.systemTemp.path}/tryon_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(jpg, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    final cam = _cam;
    if (cam != null) {
      if (cam.value.isStreamingImages) {
        cam.stopImageStream().catchError((_) {});
      }
      cam.dispose();
    }
    _hlm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Line up your hand'),
      ),
      body: _error != null
          ? _buildError()
          : !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : _buildCamera(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 60),
              const SizedBox(height: 16),
              Text(
                'Could not start the camera.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );

  Widget _buildCamera() {
    final ready = _status.isReady;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(_cam!)),
        // Hand outline guide.
        IgnorePointer(
          child: CustomPaint(painter: _HandGuidePainter(ready: ready)),
        ),
        // Status banner.
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xCC1B8A4B)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(ready ? Icons.check_circle : Icons.info_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _capturing ? 'Capturing…' : _status.message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom instruction.
        const Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Text(
            'Lay your hand flat on a plain surface and hold the phone directly '
            'above it. Spread your fingers a little. It snaps automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        if (_capturing)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Draws a semi-transparent hand silhouette the user lines their hand up with.
class _HandGuidePainter extends CustomPainter {
  final bool ready;
  _HandGuidePainter({required this.ready});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    // Guide occupies the central ~64% of the height. palmTop sits low enough
    // that even the longest finger (up to palmH above palmTop) stays on-screen
    // with a top margin that clears the status banner — earlier the fingertips
    // overshot the top edge and were clipped.
    final palmTop = h * 0.42, palmBottom = h * 0.74;
    final palmHalf = w * 0.20;

    final path = Path();
    // Palm as a rounded rectangle.
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - palmHalf, palmTop, cx + palmHalf, palmBottom),
      Radius.circular(w * 0.10),
    ));
    // Four fingers as rounded capsules radiating upward. Widths are kept below
    // the centre-to-centre spacing so adjacent fingers stay separated by a clean
    // gap — this is a lightly-spread hand, not a mitten. (Earlier the capsules
    // were wide enough to overlap, which drew the outlines crossing each other.)
    final fingers = [
      [-0.15, 0.90, 0.22], // dx frac, length frac of palm height, width frac
      [-0.05, 1.00, 0.23], // middle — longest
      [0.05, 0.95, 0.22],
      [0.15, 0.80, 0.19], // pinky — shortest, thinnest
    ];
    final palmH = palmBottom - palmTop;
    for (final f in fingers) {
      final fx = cx + w * f[0];
      final len = palmH * f[1];
      final fw = palmHalf * f[2];
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(fx - fw, palmTop - len, fx + fw, palmTop + fw),
        Radius.circular(fw),
      ));
    }
    // Thumb off to the side.
    final tw = palmHalf * 0.32;
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - palmHalf - tw * 1.4, palmTop + palmH * 0.18,
          cx - palmHalf + tw, palmTop + palmH * 0.55),
      Radius.circular(tw),
    ));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = (ready ? const Color(0xFF5BE58A) : Colors.white)
          .withValues(alpha: 0.85);
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _HandGuidePainter old) => old.ready != ready;
}
