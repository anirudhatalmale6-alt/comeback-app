import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

  // Visible 3-2-1 auto-capture countdown. 0 = not counting. Starts once the
  // hand has been aligned and held still, and cancels the moment alignment is
  // lost, so the shot is only taken from a good, stable position.
  Timer? _countdownTimer;
  int _countdown = 0;
  List<Offset>? _lastLandmarks;

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
          (c - _steadyCentroid!).distance > 0.05) {
        // Hand moved — reset the steadiness clock and abort any countdown.
        _steadyCentroid = c;
        _steadySince = DateTime.now();
        _cancelCountdown();
      } else {
        _lastLandmarks = upright;
        // Aligned and holding still: after a brief settle, start the 3-2-1.
        if (_countdownTimer == null &&
            _steadySince != null &&
            DateTime.now().difference(_steadySince!).inMilliseconds > 300) {
          _startCountdown();
        }
      }
    } else {
      _steadySince = null;
      _steadyCentroid = null;
      _cancelCountdown();
    }
    setState(() => _status = status);
  }

  /// Starts the visible 3-2-1 countdown; captures when it reaches zero.
  void _startCountdown() {
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _capturing) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        _countdownTimer = null;
        final lm = _lastLandmarks;
        if (lm != null) _autoCapture(lm);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != 0) _countdown = 0;
  }

  /// How many of the alignment checks have passed (0–5), used to fill the row
  /// of progress dots so the user can see how close they are to a good shot.
  int get _progress {
    switch (_status) {
      case CaptureCheck.noHand:
      case CaptureCheck.tooDark:
      case CaptureCheck.tooBright:
        return 0;
      case CaptureCheck.tooFar:
      case CaptureCheck.tooClose:
        return 2;
      case CaptureCheck.offCenter:
        return 3;
      case CaptureCheck.fingersTogether:
        return 4;
      case CaptureCheck.ready:
        return 5;
    }
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
    _countdownTimer?.cancel();
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
        // Dimmed surround + hand outline guide (spotlights the hand area).
        IgnorePointer(
          child: CustomPaint(
            painter: _HandGuidePainter(ready: ready, progress: _progress),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              // Close button, top-left.
              Positioned(
                top: 4,
                left: 4,
                child: _RoundIconButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              // Status pill, centered at the top.
              Positioned(
                top: 10,
                left: 60,
                right: 16,
                child: _buildStatusPill(ready),
              ),
              // Big countdown number, centered over the hand.
              if (_countdown > 0 && !_capturing)
                Center(child: _buildCountdown()),
              // Progress dots + short instruction, along the bottom.
              Positioned(
                bottom: 20,
                left: 24,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProgressDots(),
                    const SizedBox(height: 14),
                    Text(
                      ready
                          ? 'Perfect — hold still while it snaps.'
                          : 'Lay your hand flat on a plain surface, hold the '
                              'phone directly above and fit it inside the outline. '
                              'It snaps automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildStatusPill(bool ready) {
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: ready
              ? const Color(0xE60E9F53)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ready ? Icons.check_circle : Icons.pan_tool_alt_outlined,
                color: Colors.white, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _capturing
                    ? 'Capturing…'
                    : (ready ? 'Perfect!' : _status.message),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.9), width: 3),
      ),
      child: Text(
        '$_countdown',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProgressDots() {
    const green = Color(0xFF35D67F);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 5; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _progress
                  ? green
                  : Colors.white.withValues(alpha: 0.22),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7), width: 1.5),
              boxShadow: i < _progress
                  ? [
                      BoxShadow(
                          color: green.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 0.5)
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// A translucent circular button used for the corner close control.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Draws a clean, natural hand-shaped outline for the user to line their hand
/// up with, and dims everything outside it so the guide reads clearly against
/// the live camera feed. The silhouette is built by unioning tapered
/// finger/thumb "capsules" onto a rounded palm into one smooth outline, so it
/// looks like a real hand instead of a set of blocks.
class _HandGuidePainter extends CustomPainter {
  final bool ready;
  final int progress;
  _HandGuidePainter({required this.ready, required this.progress});

  /// A tapered capsule (rounded at both ends) from [a] radius [ra] to [b]
  /// radius [rb] — one finger, one thumb, or a knuckle joint.
  Path _capsule(Offset a, double ra, Offset b, double rb) {
    final p = Path();
    final d = b - a;
    final len = d.distance;
    if (len < 1e-3) {
      p.addOval(Rect.fromCircle(center: a, radius: math.max(ra, rb)));
      return p;
    }
    final dir = d / len;
    final perp = Offset(-dir.dy, dir.dx);
    final a1 = a + perp * ra, a2 = a - perp * ra;
    final b1 = b + perp * rb, b2 = b - perp * rb;
    p.moveTo(a1.dx, a1.dy);
    p.lineTo(b1.dx, b1.dy);
    p.lineTo(b2.dx, b2.dy);
    p.lineTo(a2.dx, a2.dy);
    p.close();
    p.addOval(Rect.fromCircle(center: a, radius: ra));
    p.addOval(Rect.fromCircle(center: b, radius: rb));
    return p;
  }

  Path _buildHand(Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    // Vertical band the hand occupies; leaves room for the top pill and the
    // bottom dots so nothing is clipped.
    final palmTop = h * 0.50, palmBottom = h * 0.80;
    final palmHalf = w * 0.24;
    final palmH = palmBottom - palmTop;

    // Palm — a generous rounded rectangle; finger bases sink into its top and
    // the wrist rounds off at the bottom.
    Path hand = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - palmHalf, palmTop - palmH * 0.10, cx + palmHalf,
            palmBottom),
        topLeft: Radius.circular(palmHalf * 0.5),
        topRight: Radius.circular(palmHalf * 0.5),
        bottomLeft: Radius.circular(palmHalf * 0.7),
        bottomRight: Radius.circular(palmHalf * 0.7),
      ));

    Path union(Path a, Path b) => Path.combine(PathOperation.union, a, b);

    // Four fingers: [baseX frac of palmHalf, length frac, tip X fan (frac of w),
    // base radius frac of palmHalf]. Index → pinky, middle longest.
    final fingerMax = h * 0.30;
    final fingers = <List<double>>[
      [-0.62, 0.86, -0.09, 0.30], // index
      [-0.21, 1.00, -0.03, 0.32], // middle
      [0.21, 0.92, 0.04, 0.30], // ring
      [0.62, 0.74, 0.12, 0.26], // pinky
    ];
    for (final f in fingers) {
      final base = Offset(cx + palmHalf * f[0], palmTop);
      final tip = Offset(base.dx + w * f[2], palmTop - fingerMax * f[1]);
      final rb = palmHalf * f[3];
      hand = union(hand, _capsule(base, rb, tip, rb * 0.72));
    }

    // Thumb — thicker, angled out and down to the lower-left of the palm.
    final thumbBase = Offset(cx - palmHalf * 0.80, palmTop + palmH * 0.42);
    final thumbTip = Offset(cx - palmHalf * 1.55, palmTop - fingerMax * 0.22);
    hand = union(hand, _capsule(thumbBase, palmHalf * 0.34, thumbTip,
        palmHalf * 0.22));

    return hand;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hand = _buildHand(size);

    // Dim everything outside the hand so the outline stands out.
    final surround = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hand,
    );
    canvas.drawPath(
        surround, Paint()..color = Colors.black.withValues(alpha: 0.45));

    // A faint fill inside keeps the shape legible over a busy background.
    canvas.drawPath(
        hand, Paint()..color = Colors.white.withValues(alpha: 0.05));

    final color = ready ? const Color(0xFF35D67F) : Colors.white;
    // Soft glow, then the crisp outline on top.
    canvas.drawPath(
      hand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = color.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      hand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _HandGuidePainter old) =>
      old.ready != ready || old.progress != progress;
}
