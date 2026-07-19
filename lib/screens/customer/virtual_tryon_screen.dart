import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:comeback_app/models/chat_message.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/storage_service.dart';
import 'package:comeback_app/screens/chat/chat_screen.dart';
import 'package:comeback_app/widgets/nail_overlay.dart';
import 'package:comeback_app/widgets/color_wheel_picker.dart';
import 'package:comeback_app/screens/customer/guided_capture_screen.dart';
import 'package:comeback_app/services/hand_geometry.dart';
import 'package:comeback_app/services/photo_enhance.dart';

/// A design tile bundled with the app so the try-on works with no setup.
/// [asset] doubles as the design's identity.
class BundledDesign {
  final String name;
  final String asset;
  final String category;
  const BundledDesign(this.name, this.asset, this.category);
}

/// Category order shown as chips above the design strip. 'My Uploads' is
/// appended in the UI so the customer's own images always have a home.
const List<String> kDesignCategories = [
  'Solids',
  'French',
  'Glitter',
  'Ombré',
  'Patterns',
];

/// The full built-in catalog. Every swatch is original artwork generated for
/// this app (no third-party assets), grouped by category.
const List<BundledDesign> kBundledDesigns = [
  // Solids
  BundledDesign('Classic Red', 'assets/nail_designs/classic_red.png', 'Solids'),
  BundledDesign('Ballet Pink', 'assets/nail_designs/ballet_pink.png', 'Solids'),
  BundledDesign('Nude', 'assets/nail_designs/nude_beige.png', 'Solids'),
  BundledDesign('Coral', 'assets/nail_designs/coral.png', 'Solids'),
  BundledDesign('Burgundy', 'assets/nail_designs/burgundy.png', 'Solids'),
  BundledDesign('Lilac', 'assets/nail_designs/lilac.png', 'Solids'),
  BundledDesign('Mint', 'assets/nail_designs/mint.png', 'Solids'),
  BundledDesign('Ocean Blue', 'assets/nail_designs/ocean_blue.png', 'Solids'),
  BundledDesign('Pure White', 'assets/nail_designs/pure_white.png', 'Solids'),
  BundledDesign('Midnight', 'assets/nail_designs/midnight_black.png', 'Solids'),
  // French
  BundledDesign('Classic', 'assets/nail_designs/french_tip.png', 'French'),
  BundledDesign('Pink', 'assets/nail_designs/french_pink.png', 'French'),
  BundledDesign('Gold', 'assets/nail_designs/french_gold.png', 'French'),
  BundledDesign('Black', 'assets/nail_designs/french_black.png', 'French'),
  // Glitter
  BundledDesign('Gold', 'assets/nail_designs/gold_glitter.png', 'Glitter'),
  BundledDesign('Silver', 'assets/nail_designs/silver_glitter.png', 'Glitter'),
  BundledDesign('Rose', 'assets/nail_designs/rose_glitter.png', 'Glitter'),
  BundledDesign('Holo', 'assets/nail_designs/holo_glitter.png', 'Glitter'),
  // Ombré
  BundledDesign('Sunset', 'assets/nail_designs/sunset_ombre.png', 'Ombré'),
  BundledDesign('Pink', 'assets/nail_designs/pink_ombre.png', 'Ombré'),
  BundledDesign('Blue', 'assets/nail_designs/blue_ombre.png', 'Ombré'),
  BundledDesign('Purple', 'assets/nail_designs/purple_ombre.png', 'Ombré'),
  // Patterns
  BundledDesign('Polka Dots', 'assets/nail_designs/polka_dots.png', 'Patterns'),
  BundledDesign('Stripes', 'assets/nail_designs/stripes.png', 'Patterns'),
  BundledDesign('Leopard', 'assets/nail_designs/leopard.png', 'Patterns'),
  BundledDesign('Marble', 'assets/nail_designs/marble.png', 'Patterns'),
  BundledDesign('Hearts', 'assets/nail_designs/hearts.png', 'Patterns'),
];

/// The natural nail-bed colour painted behind a French tip.
const int kFrenchBaseColor = 0xFFF2DED6;

/// A palette of nail-appropriate colours. Used as the base colour for Solids and
/// as the tip colour for French, so the customer can paint any colour instead of
/// being limited to a few baked-in swatches. Ordered reds → pinks → nudes →
/// purples → blues → greens → warms → neutrals.
const List<int> kNailPalette = [
  0xFFE23B4E, // classic red
  0xFFB01B33, // burgundy
  0xFFD81B60, // raspberry
  0xFFFF6F61, // coral
  0xFFF7A8B8, // ballet pink
  0xFFEE5DA0, // hot pink
  0xFFF2DED6, // nude
  0xFFC98A5E, // caramel
  0xFF7D4B2A, // chocolate
  0xFFB57EDC, // lilac
  0xFF7C4DFF, // purple
  0xFF3F51B5, // indigo
  0xFF2196F3, // ocean blue
  0xFF00BCD4, // teal
  0xFF26A69A, // jade
  0xFF66BB6A, // green
  0xFFCDDC39, // lime
  0xFFFFEB3B, // yellow
  0xFFFFC107, // gold
  0xFFFF9800, // orange
  0xFFFFFFFF, // white (classic French tip)
  0xFFBFC7CE, // silver
  0xFF9E9E9E, // grey
  0xFF212121, // black
];

/// The design shown before the customer picks anything (classic red solid).
const String kDefaultDesign = 'solid#e23b4e';

/// Plain background colours offered behind the Design Studio preview, so the
/// customer can pick whatever reads best against the design they're building.
/// Light neutrals first, then a couple of darks. A colour wheel tile lets them
/// dial in any other colour too. Default is the soft grey.
const List<int> kStudioBackgrounds = [
  0xFFECEFF1, // soft grey (default)
  0xFFFFFFFF, // white
  0xFFEDE7F6, // lavender
  0xFFFCE4EC, // blush pink
  0xFFE0F2F1, // mint
  0xFFFFF8E1, // cream
  0xFF37474F, // slate
  0xFF1B1B1F, // near-black
];

/// The 6-hex form of a colour, e.g. 0xFFE23B4E → "e23b4e".
String _hex6(int argb) =>
    (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

/// Builds the design id for a solid colour.
String solidDesignId(int argb) => 'solid#${_hex6(argb)}';

/// Builds the design id for a French tip in [tipArgb] over [baseArgb] (defaults
/// to the standard nude base).
String frenchDesignId(int tipArgb, [int baseArgb = kFrenchBaseColor]) =>
    'french#${_hex6(tipArgb)}#${_hex6(baseArgb)}';

/// Parses a procedural colour-design id (`solid#rrggbb` or
/// `french#tttttt#bbbbbb`); returns null for bundled-asset or upload ids.
ColorDesign? colorDesignFor(String id) {
  Color parse(String h) => Color(int.parse(h, radix: 16) | 0xFF000000);
  if (id.startsWith('solid#')) {
    return ColorDesign(parse(id.substring(6)));
  }
  if (id.startsWith('french#')) {
    final parts = id.substring(7).split('#');
    final base = parts.length > 1 ? parse(parts[1]) : const Color(kFrenchBaseColor);
    return ColorDesign(base, tip: parse(parts[0]));
  }
  return null;
}

/// A nail's base width as a fraction of the editor box, and its height-to-width
/// ratio. Kept as shared constants so auto-placement and rendering stay in sync
/// (a drift between the two would size nails wrongly).
///
/// For auto-placed nails the width works out to length / ratio, so a smaller
/// ratio = wider nail. At 0.88 the auto nail comes out a touch wider than the
/// tip→plate length, which matches a natural nail plate covering the finger
/// width: paired with the 0.52 length it caps the fingertip — full width without
/// bulging past the sides.
const double kNailBaseWidthFactor = 0.125;
const double kNailAspectRatio = 0.88;

/// Default nail length multiplier (the "Medium" preset). Bumped 1.0→1.15 on
/// tester feedback that the nails should be a bit longer to fill the nail bed.
const double kNailDefaultLengthFactor = 1.15;

/// An asset or upload design may carry a recolour suffix, e.g.
/// `assets/nail_designs/leopard.png#tint=2196f3`. These helpers split that off
/// so the base artwork can be loaded and the recolour applied separately.
String stripDesignSuffix(String id) {
  final i = id.indexOf('#tint=');
  return i < 0 ? id : id.substring(0, i);
}

/// The recolour applied to an asset design, or null if it is shown as-is.
int? designTintArgb(String id) {
  final i = id.indexOf('#tint=');
  if (i < 0) return null;
  return int.parse(id.substring(i + 6), radix: 16) | 0xFF000000;
}

/// Builds a design id that recolours [baseId] to [argb].
String tintedDesignId(String baseId, int argb) =>
    '${stripDesignSuffix(baseId)}#tint=${_hex6(argb)}';

/// Resolves a design id to an image: bundled assets keep their `assets/...`
/// path; custom uploads are absolute file paths starting with '/'. Any recolour
/// suffix is stripped first so the base artwork loads.
ImageProvider designProvider(String id) {
  final base = stripDesignSuffix(id);
  if (base.startsWith('/')) return FileImage(File(base));
  return AssetImage(base);
}

/// One design placed on a nail: where it sits, how big, and its angle.
///
/// The `init*` fields remember the pose the nail was first placed at (from the
/// auto-layout) so a single nail can be reset without disturbing the others.
class _Nail {
  Offset center;
  double scale;
  double rotation;
  String asset;
  NailShape shape;
  NailFinish finish;
  double lengthFactor;
  final Offset initCenter;
  final double initScale;
  final double initRotation;
  _Nail({
    required this.center,
    required this.scale,
    required this.rotation,
    required this.asset,
    this.shape = NailShape.oval,
    this.finish = NailFinish.gloss,
    this.lengthFactor = 1.0,
  })  : initCenter = center,
        initScale = scale,
        initRotation = rotation;

  _Nail._raw({
    required this.center,
    required this.scale,
    required this.rotation,
    required this.asset,
    required this.shape,
    required this.finish,
    required this.lengthFactor,
    required this.initCenter,
    required this.initScale,
    required this.initRotation,
  });

  /// A deep copy that PRESERVES the original auto-placed pose (init*), so Undo
  /// can restore a nail and Reset still snaps it back to where auto-layout put
  /// it — not to wherever it happened to be when the snapshot was taken.
  _Nail copy() => _Nail._raw(
        center: center,
        scale: scale,
        rotation: rotation,
        asset: asset,
        shape: shape,
        finish: finish,
        lengthFactor: lengthFactor,
        initCenter: initCenter,
        initScale: initScale,
        initRotation: initRotation,
      );
}

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  File? _photo;
  final List<_Nail> _nails = [];
  int? _selected;
  // Undo history: a stack of nail-list snapshots taken just BEFORE each edit
  // (move, resize, add, remove, recolour, shape/length). Undo pops the last.
  final List<List<_Nail>> _undoStack = [];
  static const int _kMaxUndo = 40;
  // True while a nail is being dragged, so we can show crosshair guides that
  // stay visible even when the finger covers the nail.
  bool _dragging = false;
  String? _currentDesign;
  // The shape/finish/length applied to new nails and to "all nails" edits. A
  // single selected nail can override these for that finger only.
  NailShape _shape = NailShape.oval;
  NailFinish _finish = NailFinish.gloss;
  double _lengthFactor = kNailDefaultLengthFactor;
  // Which category strip is showing, and the customer's own uploaded designs.
  String _category = kDesignCategories.first;
  // The base (background) colour used behind French tips. Palette tip taps keep
  // this base; the custom picker can change it.
  int _frenchBase = kFrenchBaseColor;
  final List<String> _customDesigns = [];
  bool _busy = false;

  // Design Studio: compose a look (design, colour, shape, finish) on an easy
  // preview BEFORE the photo, then "put it on your hand". _seedFan places the
  // composed design as a starter set on the next manually-chosen photo.
  bool _studio = false;
  bool _seedFan = false;
  // The plain colour shown behind the Studio preview (customer-changeable).
  int _studioBg = kStudioBackgrounds.first;
  // A design per finger for the Studio (index 0 = leftmost/thumb .. 4 = pinky).
  // null means that finger just uses the shared [_currentDesign]. Lets the
  // customer design each nail separately before putting the set on the hand.
  final List<String?> _studioDesigns = List<String?>.filled(5, null);
  // Which Studio nail is being designed on its own (zoomed in); null = editing
  // the whole set together.
  int? _studioFocus;

  final GlobalKey _captureKey = GlobalKey();
  Size _boxSize = Size.zero;

  // Set when a photo arrives from the guided camera: the photo's pixel size and
  // the detected hand landmarks (normalized) awaiting auto-placement.
  Size _photoImgSize = Size.zero;
  List<Offset>? _pendingLandmarks;

  // The photo's measured ambient light, applied to every painted nail so they
  // sit in the same light as the hand. Reset to neutral on each new photo and
  // filled in once the photo is decoded and averaged.
  AmbientLight _ambient = AmbientLight.neutral;

  // Baselines captured at gesture start so pinch/rotate feel natural.
  double _startScale = 1;
  double _startRot = 0;

  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source, {bool keepDesign = false}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;
    final original = File(picked.path);
    setState(() {
      _photo = original;
      _photoImgSize = Size.zero;
      _pendingLandmarks = null;
      _ambient = AmbientLight.neutral;
      _nails.clear();
      _undoStack.clear();
      _selected = null;
      // Coming from the Studio we keep the composed design so it can be laid
      // onto the photo as a starter set; otherwise start with a clean slate.
      if (!keepDesign) {
        _currentDesign = null;
        for (int i = 0; i < _studioDesigns.length; i++) {
          _studioDesigns[i] = null;
        }
      }
    });
    // Auto-enhance the photo (brighten/white-balance/sharpen) and measure its
    // light in the background; the photo swaps to the enhanced version and the
    // nails restyle once it lands. Dimensions are preserved so nothing shifts.
    try {
      final enhanced = await _enhancedPhotoFile(original);
      final bytes = await enhanced.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final ambient = await _computeAmbient(decoded);
      if (mounted) {
        setState(() {
          _photo = enhanced;
          _ambient = ambient;
        });
      }
    } catch (_) {
      // Fall back to the original photo and neutral light on any failure.
    }
  }

  /// Runs [enhanceJpgBytes] on a background isolate and writes the result to a
  /// temp file. Returns the original file unchanged if enhancement fails, so
  /// callers can use it blindly — a photo is never lost to a bad enhance.
  Future<File> _enhancedPhotoFile(File src) async {
    try {
      final bytes = await src.readAsBytes();
      final out = await compute(enhanceJpgBytes, bytes);
      final path =
          '${Directory.systemTemp.path}/tryon_enh_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(out, flush: true);
      return file;
    } catch (_) {
      return src;
    }
  }

  /// Measures the photo's average light by shrinking it to a tiny thumbnail and
  /// averaging the pixels, then turns that into a gentle per-channel scale for
  /// the nails: darker photo → darker nail, warm/cool room → warm/cool nail.
  /// Runs once per photo, entirely on-device (a downscale + average, no AI).
  Future<AmbientLight> _computeAmbient(ui.Image image) async {
    const n = 24;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final small = await recorder.endRecording().toImage(n, n);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return AmbientLight.neutral;
    final bytes = data.buffer.asUint8List();
    double rs = 0, gs = 0, bs = 0;
    int count = 0;
    for (int i = 0; i + 3 < bytes.length; i += 4) {
      final a = bytes[i + 3];
      if (a < 8) continue; // skip transparent
      rs += bytes[i];
      gs += bytes[i + 1];
      bs += bytes[i + 2];
      count++;
    }
    if (count == 0) return AmbientLight.neutral;
    final r = rs / count, g = gs / count, b = bs / count;
    final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
    final gray = (r + g + b) / 3.0;

    // Brightness: aim nails at the scene's exposure, referenced to a well-lit
    // photo (~0.55), softened toward 1 and clamped so it never crushes/blooms.
    double brightness = lum / 0.55;
    brightness = _mix(1.0, brightness, 0.55).clamp(0.80, 1.12);

    // Colour cast: how each channel deviates from neutral gray, softened and
    // clamped so the tint stays subtle (a hint of warmth, not a colour wash).
    double cast(double c) {
      final ratio = gray <= 0 ? 1.0 : c / gray;
      return _mix(1.0, ratio, 0.5).clamp(0.92, 1.10);
    }

    return AmbientLight(
      brightness * cast(r),
      brightness * cast(g),
      brightness * cast(b),
    );
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  /// Opens the guided camera; on return, loads the standardized photo and
  /// queues its detected landmarks so nails are auto-placed once the editor
  /// has laid out.
  Future<void> _openGuidedCapture({bool keepStudioDesigns = false}) async {
    final result = await Navigator.push<GuidedCaptureResult>(
      context,
      MaterialPageRoute(builder: (_) => const GuidedCaptureScreen()),
    );
    if (result == null || !mounted) return;
    // A guided capture that didn't come from the Studio starts with a clean
    // per-finger design slate.
    if (!keepStudioDesigns) {
      for (int i = 0; i < _studioDesigns.length; i++) {
        _studioDesigns[i] = null;
      }
    }
    // Auto-enhance the captured frame. Enhancement preserves dimensions, so the
    // normalized landmarks still map onto it exactly.
    final enhanced = await _enhancedPhotoFile(result.imageFile);
    final bytes = await enhanced.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    if (!mounted) return;
    final ambient = await _computeAmbient(decoded);
    if (!mounted) return;
    setState(() {
      _photo = enhanced;
      _photoImgSize =
          Size(decoded.width.toDouble(), decoded.height.toDouble());
      _pendingLandmarks = result.normalizedLandmarks;
      _ambient = ambient;
      _selected = null;
      _nails.clear();
      _undoStack.clear();
      _currentDesign ??= kDefaultDesign;
    });
  }

  /// Places one nail per detected finger, mapping landmark image coordinates
  /// into the editor box. Runs once after the photo lays out; the user can
  /// still fine-tune or Reset each nail afterwards.
  void _autoPlaceNails() {
    final lm = _pendingLandmarks;
    if (lm == null || _boxSize == Size.zero || _photoImgSize == Size.zero) {
      return;
    }
    _pendingLandmarks = null;
    final fit = FitTransform.contain(_photoImgSize, _boxSize);
    final lmImg = lm
        .map((n) =>
            Offset(n.dx * _photoImgSize.width, n.dy * _photoImgSize.height))
        .toList();
    final poses = computeNailPoses(lmImg);
    final baseW = _boxSize.width * kNailBaseWidthFactor;
    final baseH = baseW * kNailAspectRatio;
    final shared = _currentDesign ?? kDefaultDesign;
    // If the customer designed each finger separately in the Studio, match those
    // per-finger designs to the detected nails left→right (index 0 of the Studio
    // fan is the leftmost nail). Falls back to the shared design otherwise.
    final perNail = _studioDesigns.any((d) => d != null) &&
        poses.length == _studioDesigns.length;
    final designByPose = List<String>.filled(poses.length, shared);
    if (perNail) {
      final order = List<int>.generate(poses.length, (i) => i)
        ..sort((a, b) => poses[a].center.dx.compareTo(poses[b].center.dx));
      for (int rank = 0; rank < order.length; rank++) {
        designByPose[order[rank]] = _studioDesigns[rank] ?? shared;
      }
    }
    setState(() {
      _nails.clear();
      for (int i = 0; i < poses.length; i++) {
        final pose = poses[i];
        final centerBox = fit.imageToBox(pose.center);
        final lenBox = pose.length * fit.scale;
        _nails.add(_Nail(
          center: centerBox,
          scale: (lenBox / baseH).clamp(0.2, 5.0),
          rotation: pose.rotation,
          asset: designByPose[i],
          shape: _shape,
          finish: _finish,
          lengthFactor: _lengthFactor,
        ));
      }
      _currentDesign = shared;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// First design tap auto-arranges five nails in a natural fan; later taps
  /// just re-skin whatever nails are already placed.
  void _applyDesign(String asset) {
    // In the Studio (no photo yet) a design tap just updates the composed look
    // shown in the preview; nails are placed later, once there's a photo. If a
    // single nail is focused, only that finger changes; otherwise the whole set
    // takes the new design.
    if (_photo == null) {
      setState(() {
        if (_studioFocus != null) {
          _studioDesigns[_studioFocus!] = asset;
        } else {
          _currentDesign = asset;
          for (int i = 0; i < _studioDesigns.length; i++) {
            _studioDesigns[i] = null;
          }
        }
      });
      return;
    }
    _pushUndo();
    setState(() {
      _currentDesign = asset;
      if (_nails.isEmpty) {
        if (_boxSize == Size.zero) return;
        // x, y, rotation, scale - each finger gets its own size and angle so
        // the fan looks like a real spread hand (pinky/thumb smaller, middle
        // longest) rather than five identical stamps.
        const spots = [
          [0.30, 0.47, -0.50, 0.72],
          [0.42, 0.34, -0.22, 0.92],
          [0.52, 0.29, 0.00, 1.05],
          [0.63, 0.34, 0.22, 0.90],
          [0.74, 0.47, 0.50, 0.80],
        ];
        for (final s in spots) {
          _nails.add(_Nail(
            center: Offset(_boxSize.width * s[0], _boxSize.height * s[1]),
            scale: s[3].toDouble(),
            rotation: s[2].toDouble(),
            asset: asset,
            shape: _shape,
            finish: _finish,
            lengthFactor: _lengthFactor,
          ));
        }
      } else if (_selected != null) {
        // A nail is selected: re-skin just that one, so users can build a
        // custom set with a different design per finger.
        _nails[_selected!].asset = asset;
      } else {
        for (final n in _nails) {
          n.asset = asset;
        }
      }
    });
  }

  /// Lays the Studio's composed set onto a freshly-picked manual photo as a
  /// starter fan the customer drags onto each finger. Each finger keeps the
  /// design it was given in the Studio (per-nail), falling back to the shared
  /// look. The fan is placed left→right to match the Studio's finger order.
  void _seedStudioFan() {
    if (_boxSize == Size.zero) return;
    final shared = _currentDesign ?? kDefaultDesign;
    setState(() {
      _nails.clear();
      _undoStack.clear();
      _selected = null;
      const spots = [
        [0.30, 0.47, -0.50, 0.72],
        [0.42, 0.34, -0.22, 0.92],
        [0.52, 0.29, 0.00, 1.05],
        [0.63, 0.34, 0.22, 0.90],
        [0.74, 0.47, 0.50, 0.80],
      ];
      for (int i = 0; i < spots.length; i++) {
        final s = spots[i];
        _nails.add(_Nail(
          center: Offset(_boxSize.width * s[0], _boxSize.height * s[1]),
          scale: s[3].toDouble(),
          rotation: s[2].toDouble(),
          asset: _studioDesigns[i] ?? shared,
          shape: _shape,
          finish: _finish,
          lengthFactor: _lengthFactor,
        ));
      }
      _currentDesign = shared;
    });
  }

  /// The design id the strip below is currently editing: the focused finger's
  /// design in the Studio, otherwise the shared/current design. Drives which
  /// swatch shows as selected and what the custom pickers open on.
  String? _activeDesignId() {
    if (_photo == null && _studioFocus != null) {
      return _studioDesigns[_studioFocus!] ?? _currentDesign;
    }
    return _currentDesign;
  }

  /// Lets the customer bring their own inspiration image (a design they saw
  /// online, a photo from a magazine, etc.) and try it on like any swatch.
  Future<void> _pickCustomDesign() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (!_customDesigns.contains(picked.path)) {
        _customDesigns.insert(0, picked.path);
      }
    });
    _applyDesign(picked.path);
  }

  /// Snapshots the current nails so the next edit can be undone. Call BEFORE
  /// mutating [_nails].
  void _pushUndo() {
    _undoStack.add(_nails.map((n) => n.copy()).toList());
    if (_undoStack.length > _kMaxUndo) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      final prev = _undoStack.removeLast();
      _nails
        ..clear()
        ..addAll(prev);
      // Keep any still-valid selection; drop it if it now points past the end.
      if (_selected != null && _selected! >= _nails.length) _selected = null;
    });
  }

  void _addNail() {
    if (_currentDesign == null) {
      _snack('Pick a design first');
      return;
    }
    _pushUndo();
    setState(() {
      _nails.add(_Nail(
        center: Offset(_boxSize.width / 2, _boxSize.height / 2),
        scale: 1.0,
        rotation: 0,
        asset: _currentDesign!,
        shape: _shape,
        finish: _finish,
        lengthFactor: _lengthFactor,
      ));
      _selected = _nails.length - 1;
    });
  }

  void _removeSelected() {
    if (_selected == null) return;
    _pushUndo();
    setState(() {
      _nails.removeAt(_selected!);
      _selected = null;
    });
  }

  /// Snap just the selected nail back to the pose the auto-layout gave it,
  /// leaving every other nail untouched.
  void _resetSelected() {
    if (_selected == null) return;
    _pushUndo();
    setState(() {
      final n = _nails[_selected!];
      n.center = n.initCenter;
      n.scale = n.initScale;
      n.rotation = n.initRotation;
    });
  }

  void _reset() {
    setState(() {
      _nails.clear();
      _undoStack.clear();
      _selected = null;
      _currentDesign = null;
      _shape = NailShape.oval;
      _finish = NailFinish.gloss;
      _lengthFactor = kNailDefaultLengthFactor;
      _studio = false;
      _seedFan = false;
      _studioFocus = null;
      for (int i = 0; i < _studioDesigns.length; i++) {
        _studioDesigns[i] = null;
      }
      // Keep _ambient: the same photo (and its light) is still loaded.
    });
  }

  /// Applies a shape to the selected nail only, or to every nail (and future
  /// nails) when nothing is selected.
  void _applyShape(NailShape shape) {
    _pushUndo();
    setState(() {
      if (_selected != null) {
        _nails[_selected!].shape = shape;
      } else {
        _shape = shape;
        for (final n in _nails) {
          n.shape = shape;
        }
      }
    });
  }

  /// Applies a finish to the selected nail only, or to every nail (and future
  /// nails) when nothing is selected — same behaviour as [_applyShape].
  void _applyFinish(NailFinish finish) {
    _pushUndo();
    setState(() {
      if (_selected != null) {
        _nails[_selected!].finish = finish;
      } else {
        _finish = finish;
        for (final n in _nails) {
          n.finish = finish;
        }
      }
    });
  }

  /// Applies a length multiplier (Short/Medium/Long) with the same
  /// selected-nail-vs-all behaviour as [_applyShape].
  void _applyLength(double factor) {
    _pushUndo();
    setState(() {
      if (_selected != null) {
        _nails[_selected!].lengthFactor = factor;
      } else {
        _lengthFactor = factor;
        for (final n in _nails) {
          n.lengthFactor = factor;
        }
      }
    });
  }

  Future<void> _openShapeSheet() async {
    final sel = _selected != null ? _nails[_selected!] : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ShapeLengthSheet(
        target: sel != null
            ? 'this nail'
            : (_nails.isEmpty ? 'new nails' : 'all nails'),
        initialShape: sel?.shape ?? _shape,
        initialFinish: sel?.finish ?? _finish,
        initialLength: sel?.lengthFactor ?? _lengthFactor,
        onShape: _applyShape,
        onFinish: _applyFinish,
        onLength: _applyLength,
      ),
    );
  }

  Future<Uint8List?> _capture() async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    // Drop the selection chrome so it isn't baked into the saved image.
    setState(() => _selected = null);
    await Future.delayed(const Duration(milliseconds: 80));
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: dpr.clamp(2.0, 3.0));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _saveToAlbum() async {
    if (_nails.isEmpty) {
      _snack('Add a design to your nails first');
      return;
    }
    final storage = context.read<StorageService>();
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw 'Could not render the image';
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = await storage.uploadData(
        'customer_nails/$uid/tryon_$ts.png',
        bytes,
      );
      await FirebaseFirestore.instance.collection('customer_nail_photos').add({
        'customerUserId': uid,
        'photoUrl': url,
        'note': 'Virtual Try-On',
        'source': 'tryon',
        'createdAt': Timestamp.now(),
      });
      _snack('Saved to your album 💅');
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendToTechnician() async {
    if (_nails.isEmpty) {
      _snack('Add a design to your nails first');
      return;
    }
    final salon = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _SalonPickerSheet(),
    );
    if (salon == null || !mounted) return;

    final firestore = context.read<FirestoreService>();
    final storage = context.read<StorageService>();
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw 'Could not render the image';
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final ownerId = salon['ownerUserId'] as String;
      final salonName = (salon['businessName'] as String?) ?? 'Salon';
      final roomId = firestore.getChatRoomId(myUid, ownerId);
      final msgId = const Uuid().v4();
      final url = await storage.uploadData(
        'chat_images/$roomId/$msgId.png',
        bytes,
      );
      await firestore.sendMessage(ChatMessage(
        id: msgId,
        senderId: myUid,
        senderName: '',
        text: "Here's a nail look I'd love to try 💅",
        timestamp: DateTime.now(),
        chatRoomId: roomId,
        imageUrl: url,
      ));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: ownerId,
            otherUserName: salonName,
          ),
        ),
      );
    } catch (e) {
      _snack('Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Nail Try-On'),
        leading: _studio && _photo == null
            ? BackButton(onPressed: () => setState(() {
                // Step out of a focused nail back to the whole set first; a
                // second back leaves the Studio.
                if (_studioFocus != null) {
                  _studioFocus = null;
                } else {
                  _studio = false;
                }
              }))
            : null,
        actions: [
          if (_photo != null || _studio)
            IconButton(
              tooltip: 'Shape, finish & length',
              icon: const Icon(Icons.brush_outlined),
              onPressed: _busy ? null : _openShapeSheet,
            ),
          if (_photo != null)
            IconButton(
              tooltip: 'Start over',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _reset,
            ),
        ],
      ),
      body: _photo != null
          ? _buildEditor()
          : (_studio ? _buildStudio() : _buildChooser()),
    );
  }

  Widget _buildChooser() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.back_hand_outlined,
                size: 84, color: Colors.pink.shade200),
            const SizedBox(height: 20),
            const Text(
              'Try nail designs on your own hand',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Take or upload a clear photo of your hand with your '
              'fingers spread, then try on any design.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => setState(() {
                _studio = true;
                _studioFocus = null;
                for (int i = 0; i < _studioDesigns.length; i++) {
                  _studioDesigns[i] = null;
                }
                _currentDesign ??= kDefaultDesign;
              }),
              icon: const Icon(Icons.brush),
              label: const Text('Design My Nails First'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(240, 50),
                backgroundColor: const Color(0xFF00897B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick your colours & design on a big preview, then put it '
              'on your hand',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (Platform.isAndroid) ...[
              FilledButton.icon(
                onPressed: _openGuidedCapture,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto Try-On (Beta)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(240, 50),
                  backgroundColor: const Color(0xFF7E57C2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Guided camera — finds your nails automatically',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 18),
            ],
            FilledButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take a Photo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Upload from Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One nail rendered from the currently composed look, for the Studio
  /// preview. Everything is authored tip-up, so it renders straight — the same
  /// way it lands on the hand. [design] overrides the shared look for a single
  /// finger (per-nail Studio design).
  Widget _previewNail(double w, double h, {String? design}) {
    final cd = design ?? _currentDesign ?? kDefaultDesign;
    final color = colorDesignFor(cd);
    final tintArgb = designTintArgb(cd);
    return SizedBox(
      width: w,
      height: h,
      child: NailOverlay(
        image: color == null ? designProvider(cd) : null,
        color: color,
        tint: tintArgb == null ? null : Color(tintArgb),
        shape: _shape,
        finish: _finish,
      ),
    );
  }

  /// The Design Studio: compose a look on a big, easy preview (no fiddling on
  /// tiny nails over a hand photo), then "put it on your hand".
  Widget _buildStudio() {
    // Text/handles read differently on a light vs dark background, so pick a
    // legible foreground for whichever plain colour the customer chose.
    final onBg = ThemeData.estimateBrightnessForColor(Color(_studioBg)) ==
            Brightness.dark
        ? Colors.white70
        : Colors.black54;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Color(_studioBg),
            child: _studioFocus == null
                ? _buildStudioOverview(onBg)
                : _buildStudioFocus(onBg),
          ),
        ),
        _buildCategoryChips(),
        _buildDesignStrip(),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: Colors.white,
            child: FilledButton.icon(
              onPressed: _leaveStudioToCapture,
              icon: const Icon(Icons.back_hand),
              label: const Text('Put On My Hand'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF00897B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The whole-set view: a big, width-filling fan of the five nails. Tapping a
  /// nail zooms in to design just that finger.
  Widget _buildStudioOverview(Color onBg) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) {
                const scales = [0.82, 0.93, 1.0, 0.92, 0.84];
                const gap = 8.0;
                final totalScale = scales.fold<double>(0, (a, b) => a + b);
                final avail = c.maxWidth - 28 - gap * (scales.length - 1);
                final unit = (avail / totalScale).clamp(40.0, 104.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < scales.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == scales.length - 1 ? 0 : gap),
                        child: GestureDetector(
                          onTap: () => setState(() => _studioFocus = i),
                          child: _previewNail(
                              unit * scales[i], unit * scales[i] * 1.5,
                              design: _studioDesigns[i]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Design the whole set, or tap one nail to design it on its own. '
            'Use the brush (top right) for shape & finish.',
            textAlign: TextAlign.center,
            style: TextStyle(color: onBg, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        _buildStudioBgStrip(),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Zoomed-in view of a single finger, so it can be designed on its own. A
  /// colour/design tap or recolour applies only to this nail.
  Widget _buildStudioFocus(Color onBg) {
    final i = _studioFocus!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _studioFocus = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('All nails'),
                style: TextButton.styleFrom(foregroundColor: onBg),
              ),
              const Spacer(),
              Text('Nail ${i + 1} of 5',
                  style: TextStyle(
                      color: onBg, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth * 0.42).clamp(90.0, 170.0);
                return _previewNail(w, w * 1.5, design: _studioDesigns[i]);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Pick a colour or design for this nail only. Tap "All nails" to go '
            'back to the full set.',
            textAlign: TextAlign.center,
            style: TextStyle(color: onBg, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        _buildStudioBgStrip(),
        const SizedBox(height: 10),
      ],
    );
  }

  /// A horizontal strip of plain background colours (led by a colour-wheel tile
  /// for any custom colour) so the customer can change the Studio backdrop to
  /// whatever reads best behind the design they're building.
  Widget _buildStudioBgStrip() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _studioBgDot(custom: true),
          for (final c in kStudioBackgrounds) _studioBgDot(color: c),
        ],
      ),
    );
  }

  Widget _studioBgDot({int? color, bool custom = false}) {
    final selected = color != null && _studioBg == color;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () async {
          if (custom) {
            final picked = await showColorWheelDialog(context,
                initial: Color(_studioBg), title: 'Background colour');
            if (picked != null) {
              setState(() => _studioBg = picked.toARGB32());
            }
          } else {
            setState(() => _studioBg = color!);
          }
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: custom ? null : Color(color!),
            gradient: custom
                ? const SweepGradient(colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ])
                : null,
            border: Border.all(
              color: selected ? const Color(0xFF00897B) : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
          child: custom
              ? const Icon(Icons.colorize, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  /// After composing in the Studio, pick how to add the hand photo. The
  /// composed design is carried over: Auto Try-On applies it to the detected
  /// nails; a manual photo gets it as a starter fan to drag into place.
  void _leaveStudioToCapture() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add your hand photo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Color(0xFF7E57C2)),
                title: const Text('Auto Try-On (Beta)'),
                subtitle:
                    const Text('Guided camera finds your nails automatically'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _studio = false;
                    _studioFocus = null;
                  });
                  _openGuidedCapture(keepStudioDesigns: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00897B)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _studio = false;
                  _studioFocus = null;
                  _seedFan = true;
                });
                _pickPhoto(ImageSource.camera, keepDesign: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF00897B)),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _studio = false;
                  _studioFocus = null;
                  _seedFan = true;
                });
                _pickPhoto(ImageSource.gallery, keepDesign: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF1B1B1F),
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _boxSize = Size(constraints.maxWidth, constraints.maxHeight);
                if (_pendingLandmarks != null) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _autoPlaceNails());
                } else if (_seedFan &&
                    _nails.isEmpty &&
                    _currentDesign != null) {
                  // Came from the Studio with a manual photo: lay the composed
                  // design down as a starter fan the customer can then drag onto
                  // each finger.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_seedFan || !mounted) return;
                    _seedFan = false;
                    _seedStudioFan();
                  });
                }
                return RepaintBoundary(
                  key: _captureKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Image.file(_photo!, fit: BoxFit.contain),
                      ),
                      // Full-photo gesture layer, UNDER the nails. A tap on empty
                      // space deselects; a DRAG on empty space moves the selected
                      // nail — so you can drag from the side of the screen and
                      // watch it land via the guide lines, without your finger
                      // covering the nail. (Touching a nail still selects/moves
                      // that nail, since its own handler sits above this layer.)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_selected != null) {
                              setState(() => _selected = null);
                            }
                          },
                          onScaleStart: (_) {
                            if (_selected == null) return;
                            _pushUndo();
                            setState(() => _dragging = true);
                          },
                          onScaleUpdate: (d) {
                            if (_selected == null ||
                                _selected! >= _nails.length) {
                              return;
                            }
                            setState(() =>
                                _nails[_selected!].center += d.focalPointDelta);
                          },
                          onScaleEnd: (_) {
                            if (_selected == null) return;
                            setState(() => _dragging = false);
                          },
                        ),
                      ),
                      for (int i = 0; i < _nails.length; i++)
                        _buildNail(i, _boxSize),
                      // Crosshair guides while dragging so you can see exactly
                      // where the nail lands even under your fingertip.
                      if (_dragging &&
                          _selected != null &&
                          _selected! < _nails.length)
                        _buildDragGuides(_nails[_selected!].center),
                      if (_currentDesign == null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Pick a design below to try it on',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _buildToolbar(),
        // Always rendered at a constant height so selecting/deselecting a nail
        // never resizes the photo above it (which would rescale the photo and
        // pull the nails off the fingers).
        _buildPerNailHint(),
        _buildCategoryChips(),
        _buildDesignStrip(),
        _buildActions(),
      ],
    );
  }

  // Smallest comfortable touch target (logical px). A small nail is only ~30px
  // wide, which is hard to tap; the hit box is padded out to at least this so
  // the nail is easy to select and drag even when the artwork is tiny.
  static const double _kMinTouch = 48;

  /// Crosshair + centre ring shown while a nail is being dragged. The lines
  /// span the whole photo so the exact target point stays visible even when the
  /// fingertip covers the nail ("hard to see where you're putting them").
  /// Non-interactive (IgnorePointer) so it never eats the drag.
  Widget _buildDragGuides(Offset c) {
    const line = Color(0xCC00E5FF); // cyan ~80% — reads over skin and nails
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: c.dy - 0.75,
            height: 1.5,
            child: Container(color: line),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: c.dx - 0.75,
            width: 1.5,
            child: Container(color: line),
          ),
          Positioned(
            left: c.dx - 9,
            top: c.dy - 9,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: line, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNail(int i, Size box) {
    final n = _nails[i];
    final baseW = box.width * kNailBaseWidthFactor;
    final baseH = baseW * kNailAspectRatio;
    final w = baseW * n.scale;
    // Length is a style choice on top of the auto-fitted size: longer nails
    // extend the free-edge without changing the nail's width.
    final h = baseH * n.scale * n.lengthFactor;
    final selected = _selected == i;

    // The hit box is the nail padded out to a minimum touch size and centred on
    // the same point, so tapping/dragging is easy without enlarging the artwork.
    final hitW = math.max(w, _kMinTouch);
    final hitH = math.max(h, _kMinTouch);

    return Positioned(
      left: n.center.dx - hitW / 2,
      top: n.center.dy - hitH / 2,
      width: hitW,
      height: hitH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The nail artwork, at its true size, centred in the hit box. Rotate
          // around its own centre (the box is centred on the finger's nail
          // centre) - rotating about an edge would swing it off the target as
          // the finger angle grows (the thumb/pinky "floating nail" bug).
          SizedBox(
            width: w,
            height: h,
            child: Transform.rotate(
              // Both the bundled PNG artwork and the procedurally-painted colour
              // designs are authored tip-UP (free-edge at the top), matching the
              // nail silhouette. So a nail just takes its own rotation with no
              // extra half-turn. (An earlier half-turn for artwork flipped the
              // design upside down and swung auto-placed nails toward the
              // knuckle instead of the fingertip.)
              angle: n.rotation,
              alignment: Alignment.center,
              child: NailOverlay(
                  image: colorDesignFor(n.asset) == null
                      ? designProvider(n.asset)
                      : null,
                  color: colorDesignFor(n.asset),
                  tint: designTintArgb(n.asset) == null
                      ? null
                      : Color(designTintArgb(n.asset)!),
                  shape: n.shape,
                  finish: n.finish,
                  ambient: _ambient),
            ),
          ),
          if (selected)
            IgnorePointer(
              child: SizedBox(
                width: w,
                height: h,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          // Full hit box: the enlarged, easy-to-hit tap/drag target.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selected = i),
              onScaleStart: (_) {
                _startScale = n.scale;
                _startRot = n.rotation;
                // One undo snapshot per drag/pinch gesture (not per frame).
                _pushUndo();
                setState(() {
                  _selected = i;
                  _dragging = true;
                });
              },
              onScaleUpdate: (d) {
                setState(() {
                  n.center += d.focalPointDelta;
                  n.scale = (_startScale * d.scale).clamp(0.35, 4.0);
                  n.rotation = _startRot + d.rotation;
                });
              },
              onScaleEnd: (_) => setState(() => _dragging = false),
            ),
          ),
          if (selected)
            Positioned(
              // Hug the artwork's top-right corner within the padded hit box.
              top: (hitH - h) / 2 - 14,
              right: (hitW - w) / 2 - 14,
              child: GestureDetector(
                onTap: _removeSelected,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _addNail,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add nail'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Change photo'),
          ),
          TextButton.icon(
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Undo'),
          ),
          const Spacer(),
          if (_selected != null) ...[
            TextButton.icon(
              onPressed: _resetSelected,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset'),
            ),
            TextButton.icon(
              onPressed: _removeSelected,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              label: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  // Constant height of the per-nail control bar. Fixed so the photo area above
  // it never changes size when a nail is selected/deselected — otherwise the
  // photo rescales and the placed nails no longer line up with the fingers.
  static const double _kHintHeight = 104;

  Widget _buildPerNailHint() {
    // When a nail is selected, show Size and Angle sliders so it can be resized
    // and rotated reliably. Pinch/twist gestures also work, but on a small nail
    // the target is tiny, so the sliders are the dependable controls. Drag still
    // moves it.
    if (_selected != null && _selected! < _nails.length) {
      final n = _nails[_selected!];
      return Container(
        width: double.infinity,
        height: _kHintHeight,
        color: const Color(0xFFEDE7F6),
        padding: const EdgeInsets.only(left: 12, right: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.zoom_out_map,
                    size: 16, color: Color(0xFF5E35B1)),
                const SizedBox(width: 4),
                const SizedBox(
                    width: 40,
                    child: Text('Size', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: n.scale.clamp(0.35, 4.0),
                    min: 0.35,
                    max: 4.0,
                    onChangeStart: (_) => _pushUndo(),
                    onChanged: (v) => setState(() => n.scale = v),
                  ),
                ),
                // Explicit way to dismiss the selection (and its X badge)
                // without deleting the nail. Tapping empty photo space too.
                TextButton(
                  onPressed: () => setState(() => _selected = null),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: const Color(0xFF5E35B1),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 2),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.rotate_right,
                    size: 16, color: Color(0xFF5E35B1)),
                const SizedBox(width: 4),
                const SizedBox(
                    width: 40,
                    child: Text('Angle', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: n.rotation.clamp(-math.pi, math.pi),
                    min: -math.pi,
                    max: math.pi,
                    onChangeStart: (_) => _pushUndo(),
                    onChanged: (v) => setState(() => n.rotation = v),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => n.rotation = n.initRotation),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: const Color(0xFF5E35B1),
                  ),
                  child: const Text('Straighten', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: _kHintHeight,
      alignment: Alignment.center,
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        _nails.isEmpty
            ? 'Pick a design below to place your nails, then tap a nail to '
                'move, resize or angle it.'
            : 'Tip: tap a nail to select it, then drag anywhere (even the side '
                'of the screen) to move it — guide lines show where it lands. '
                'Tap empty space or Done to deselect.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = [...kDesignCategories, 'My Uploads'];
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = cats[i];
          final active = _category == c;
          return GestureDetector(
            onTap: () => setState(() => _category = c),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF00897B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? const Color(0xFF00897B) : Colors.grey.shade300,
                ),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesignStrip() {
    // Solids and French are painted from the colour palette so any colour is
    // available (base colour for Solids, tip colour for French).
    if (_category == 'Solids' || _category == 'French') {
      return _buildColorPalette(french: _category == 'French');
    }
    final isUploads = _category == 'My Uploads';
    final designs =
        kBundledDesigns.where((d) => d.category == _category).toList();
    // Every artwork strip leads with a special tile: "Upload" for My Uploads,
    // "Recolour" (the colour wheel) for the built-in categories so any design
    // can be dialled to an exact colour. The rest are the design swatches.
    final itemCount =
        isUploads ? _customDesigns.length + 1 : designs.length + 1;

    return Container(
      height: 92,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return isUploads ? _buildUploadTile() : _buildRecolorTile();
          }
          final id = isUploads ? _customDesigns[i - 1] : designs[i - 1].asset;
          final name = isUploads ? 'My photo' : designs[i - 1].name;
          return _buildDesignTile(id, name);
        },
      ),
    );
  }

  /// A horizontal palette of colours led by a "Custom" wheel tile. For Solids
  /// each swatch paints the whole nail; for French each swatch sets the tip
  /// colour over the current base.
  Widget _buildColorPalette({required bool french}) {
    return Container(
      height: 92,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kNailPalette.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) return _buildCustomColorTile(french: french);
          final argb = kNailPalette[i - 1] | 0xFF000000;
          final id =
              french ? frenchDesignId(argb, _frenchBase) : solidDesignId(argb);
          final active = _activeDesignId() == id;
          final design = french
              ? ColorDesign(Color(_frenchBase), tip: Color(argb))
              : ColorDesign(Color(argb));
          return Center(
            child: GestureDetector(
              onTap: () => _applyDesign(id),
              child: Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        active ? const Color(0xFF00897B) : Colors.grey.shade300,
                    width: active ? 2.5 : 1,
                  ),
                ),
                child: NailColorSwatch(design),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The leading palette tile: a rainbow wheel that opens the colour picker so
  /// the customer can dial in any exact colour (and, for French, the base too).
  Widget _buildCustomColorTile({required bool french}) {
    return Center(
      child: GestureDetector(
        onTap: french ? _pickFrenchCustom : _pickSolidCustom,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                gradient: const SweepGradient(colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ]),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 2),
            const Text('Custom', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// Solids: pick any exact colour with the wheel and paint the whole nail.
  Future<void> _pickSolidCustom() async {
    final activeId = _activeDesignId();
    final cd = activeId == null ? null : colorDesignFor(activeId);
    final start = (cd != null && cd.tip == null) ? cd.base : const Color(0xFFE23B4E);
    final picked =
        await showColorWheelDialog(context, initial: start, title: 'Nail colour');
    if (picked == null) return;
    _applyDesign(solidDesignId(picked.toARGB32()));
  }

  /// French: choose both the tip colour and the base colour, each with the
  /// wheel, and preview the result live before applying.
  Future<void> _pickFrenchCustom() async {
    final activeId = _activeDesignId();
    final cd = activeId == null ? null : colorDesignFor(activeId);
    Color tip = (cd != null && cd.tip != null) ? cd.tip! : const Color(0xFFFFFFFF);
    Color base = (cd != null && cd.tip != null) ? cd.base : Color(_frenchBase);

    final applied = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget swatchRow(String label, Color color, VoidCallback onTap) {
              return InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(label, style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.edit, size: 18, color: Colors.black45),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Custom French',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Center(
                      child: SizedBox(
                        width: 64,
                        height: 90,
                        child: NailColorSwatch(ColorDesign(base, tip: tip)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    swatchRow('Tip colour', tip, () async {
                      final c = await showColorWheelDialog(ctx,
                          initial: tip, title: 'Tip colour');
                      if (c != null) setSheet(() => tip = c);
                    }),
                    const Divider(height: 1),
                    swatchRow('Base colour', base, () async {
                      final c = await showColorWheelDialog(ctx,
                          initial: base, title: 'Base colour');
                      if (c != null) setSheet(() => base = c);
                    }),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true) {
      setState(() => _frenchBase = base.toARGB32());
      _applyDesign(frenchDesignId(tip.toARGB32(), base.toARGB32()));
    }
  }

  /// Leading tile for the artwork categories: a colour-wheel button that
  /// recolours the showing design (or the first in the category) to any exact
  /// colour, keeping its texture. Highlighted while a recolour is active.
  Widget _buildRecolorTile() {
    final activeId = _activeDesignId();
    final tinted = activeId != null && designTintArgb(activeId) != null;
    return Center(
      child: GestureDetector(
        onTap: _pickRecolor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      tinted ? const Color(0xFF00897B) : Colors.grey.shade300,
                  width: tinted ? 2.5 : 1,
                ),
                gradient: const SweepGradient(colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ]),
              ),
              child: const Icon(Icons.brush, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 2),
            const Text('Recolour', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// Recolours the current design (a glitter, ombré or pattern) to any exact
  /// colour via the wheel. Works on whichever artwork is showing; if none in
  /// this category is picked yet, it recolours the first one.
  Future<void> _pickRecolor() async {
    final designs =
        kBundledDesigns.where((d) => d.category == _category).toList();
    if (designs.isEmpty) return;
    final activeId = _activeDesignId();
    final cur = activeId == null ? null : stripDesignSuffix(activeId);
    final base = (cur != null && designs.any((d) => d.asset == cur))
        ? cur
        : designs.first.asset;
    final curTint = activeId == null ? null : designTintArgb(activeId);
    final start = Color(curTint ?? 0xFFEE5DA0);
    final picked = await showColorWheelDialog(context,
        initial: start, title: 'Recolour design');
    if (picked == null) return;
    _applyDesign(tintedDesignId(base, picked.toARGB32()));
  }

  Widget _buildDesignTile(String id, String name) {
    // Compare on the base path so the underlying swatch still reads as selected
    // even when a recolour suffix is applied to the live design.
    final activeId = _activeDesignId();
    final active = activeId != null && stripDesignSuffix(activeId) == id;
    return GestureDetector(
      onTap: () => _applyDesign(id),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? const Color(0xFF00897B) : Colors.grey.shade300,
                width: active ? 2.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image(image: designProvider(id), fit: BoxFit.cover),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile() {
    return GestureDetector(
      onTap: _pickCustomDesign,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00897B)),
            ),
            child: const Icon(Icons.add_a_photo_outlined,
                color: Color(0xFF00897B)),
          ),
          const SizedBox(height: 4),
          const SizedBox(
            width: 56,
            child: Text('Upload',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveToAlbum,
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _sendToTechnician,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send to Technician'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that lets the customer search and pick a salon to send the
/// look to. The salon's owner receives it as a chat image.
class _SalonPickerSheet extends StatefulWidget {
  const _SalonPickerSheet();

  @override
  State<_SalonPickerSheet> createState() => _SalonPickerSheetState();
}

class _SalonPickerSheetState extends State<_SalonPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final firestore = context.read<FirestoreService>();
      final results = await firestore.searchSalons(q);
      if (!mounted) return;
      setState(() {
        _results = results.where((s) => s['ownerUserId'] != null).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Send to which salon?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search salons...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => _load(v),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No salons found',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final s = _results[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE0F2F1),
                                child: const Icon(Icons.store,
                                    color: Color(0xFF00897B)),
                              ),
                              title: Text(s['businessName'] ?? 'Salon'),
                              subtitle: Text(
                                s['address'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a nail shape (9 salon shapes), finish (Gloss, Matte,
/// Chrome, Cat Eye, Jelly, Glitter, Velvet) and length (Short/Medium/Long).
/// Changes apply live as they're tapped so the customer sees them on the photo
/// behind the sheet. The shape and finish rows scroll horizontally.
class _ShapeLengthSheet extends StatefulWidget {
  final String target;
  final NailShape initialShape;
  final NailFinish initialFinish;
  final double initialLength;
  final ValueChanged<NailShape> onShape;
  final ValueChanged<NailFinish> onFinish;
  final ValueChanged<double> onLength;
  const _ShapeLengthSheet({
    required this.target,
    required this.initialShape,
    required this.initialFinish,
    required this.initialLength,
    required this.onShape,
    required this.onFinish,
    required this.onLength,
  });

  @override
  State<_ShapeLengthSheet> createState() => _ShapeLengthSheetState();
}

class _ShapeLengthSheetState extends State<_ShapeLengthSheet> {
  static const _lengths = [
    ('Short', 0.90),
    ('Medium', kNailDefaultLengthFactor), // 1.15 — the new default
    ('Long', 1.45),
  ];

  late NailShape _shape = widget.initialShape;
  late NailFinish _finish = widget.initialFinish;
  late double _length = widget.initialLength;

  static const _teal = Color(0xFF00897B);

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  Widget _shapeRow() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: NailShape.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = NailShape.values[i];
          final active = _shape == s;
          return GestureDetector(
            onTap: () {
              setState(() => _shape = s);
              widget.onShape(s);
            },
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 74,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? _teal : Colors.grey.shade300,
                      width: active ? 2.5 : 1,
                    ),
                  ),
                  child: NailShapePreview(shape: s, finish: _finish),
                ),
                const SizedBox(height: 4),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: active ? _teal : Colors.grey.shade700,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _finishRow() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: NailFinish.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = NailFinish.values[i];
          final active = _finish == f;
          return GestureDetector(
            onTap: () {
              setState(() => _finish = f);
              widget.onFinish(f);
            },
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 60,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? _teal : Colors.grey.shade300,
                      width: active ? 2.5 : 1,
                    ),
                  ),
                  // A rounded swatch showing the finish on a rich colour.
                  child: NailShapePreview(
                    shape: NailShape.squoval,
                    finish: f,
                    color: const Color(0xFFC0304A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: active ? _teal : Colors.grey.shade700,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Shape, finish & length — applies to ${widget.target}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _sectionTitle('Shape'),
              const SizedBox(height: 8),
              _shapeRow(),
              const SizedBox(height: 16),
              _sectionTitle('Finish'),
              const SizedBox(height: 8),
              _finishRow(),
              const SizedBox(height: 16),
              _sectionTitle('Length'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final l in _lengths) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _length = l.$2);
                          widget.onLength(l.$2);
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                _length == l.$2 ? _teal : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            l.$1,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _length == l.$2
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (l != _lengths.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
