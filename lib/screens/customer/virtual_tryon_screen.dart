import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'package:comeback_app/screens/customer/guided_capture_screen.dart';
import 'package:comeback_app/services/hand_geometry.dart';

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

/// The design shown before the customer picks anything.
const String kDefaultDesign = 'assets/nail_designs/classic_red.png';

/// Resolves a design id to an image: bundled assets keep their `assets/...`
/// path; custom uploads are absolute file paths starting with '/'.
ImageProvider designProvider(String id) {
  if (id.startsWith('/')) return FileImage(File(id));
  return AssetImage(id);
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
  double lengthFactor;
  final Offset initCenter;
  final double initScale;
  final double initRotation;
  _Nail({
    required this.center,
    required this.scale,
    required this.rotation,
    required this.asset,
    this.shape = NailShape.almond,
    this.lengthFactor = 1.0,
  })  : initCenter = center,
        initScale = scale,
        initRotation = rotation;
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
  String? _currentDesign;
  // The shape/length applied to new nails and to "all nails" edits. A single
  // selected nail can override these for that finger only.
  NailShape _shape = NailShape.almond;
  double _lengthFactor = 1.0;
  // Which category strip is showing, and the customer's own uploaded designs.
  String _category = kDesignCategories.first;
  final List<String> _customDesigns = [];
  bool _busy = false;

  final GlobalKey _captureKey = GlobalKey();
  Size _boxSize = Size.zero;

  // Set when a photo arrives from the guided camera: the photo's pixel size and
  // the detected hand landmarks (normalized) awaiting auto-placement.
  Size _photoImgSize = Size.zero;
  List<Offset>? _pendingLandmarks;

  // Baselines captured at gesture start so pinch/rotate feel natural.
  double _startScale = 1;
  double _startRot = 0;

  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _photo = File(picked.path);
      _photoImgSize = Size.zero;
      _pendingLandmarks = null;
      _nails.clear();
      _selected = null;
      _currentDesign = null;
    });
  }

  /// Opens the guided camera; on return, loads the standardized photo and
  /// queues its detected landmarks so nails are auto-placed once the editor
  /// has laid out.
  Future<void> _openGuidedCapture() async {
    final result = await Navigator.push<GuidedCaptureResult>(
      context,
      MaterialPageRoute(builder: (_) => const GuidedCaptureScreen()),
    );
    if (result == null || !mounted) return;
    final bytes = await result.imageFile.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      _photo = result.imageFile;
      _photoImgSize =
          Size(decoded.width.toDouble(), decoded.height.toDouble());
      _pendingLandmarks = result.normalizedLandmarks;
      _selected = null;
      _nails.clear();
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
    final baseW = _boxSize.width * 0.12;
    final baseH = baseW * 1.45;
    final asset = _currentDesign ?? kDefaultDesign;
    setState(() {
      _nails.clear();
      for (final pose in poses) {
        final centerBox = fit.imageToBox(pose.center);
        final lenBox = pose.length * fit.scale;
        _nails.add(_Nail(
          center: centerBox,
          scale: (lenBox / baseH).clamp(0.2, 5.0),
          rotation: pose.rotation,
          asset: asset,
          shape: _shape,
          lengthFactor: _lengthFactor,
        ));
      }
      _currentDesign = asset;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// First design tap auto-arranges five nails in a natural fan; later taps
  /// just re-skin whatever nails are already placed.
  void _applyDesign(String asset) {
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

  void _addNail() {
    if (_currentDesign == null) {
      _snack('Pick a design first');
      return;
    }
    setState(() {
      _nails.add(_Nail(
        center: Offset(_boxSize.width / 2, _boxSize.height / 2),
        scale: 1.0,
        rotation: 0,
        asset: _currentDesign!,
        shape: _shape,
        lengthFactor: _lengthFactor,
      ));
      _selected = _nails.length - 1;
    });
  }

  void _removeSelected() {
    if (_selected == null) return;
    setState(() {
      _nails.removeAt(_selected!);
      _selected = null;
    });
  }

  /// Snap just the selected nail back to the pose the auto-layout gave it,
  /// leaving every other nail untouched.
  void _resetSelected() {
    if (_selected == null) return;
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
      _selected = null;
      _currentDesign = null;
      _shape = NailShape.almond;
      _lengthFactor = 1.0;
    });
  }

  /// Applies a shape to the selected nail only, or to every nail (and future
  /// nails) when nothing is selected.
  void _applyShape(NailShape shape) {
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

  /// Applies a length multiplier (Short/Medium/Long) with the same
  /// selected-nail-vs-all behaviour as [_applyShape].
  void _applyLength(double factor) {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ShapeLengthSheet(
        target: sel != null
            ? 'this nail'
            : (_nails.isEmpty ? 'new nails' : 'all nails'),
        initialShape: sel?.shape ?? _shape,
        initialLength: sel?.lengthFactor ?? _lengthFactor,
        onShape: _applyShape,
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
        actions: [
          if (_photo != null)
            IconButton(
              tooltip: 'Nail shape & length',
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
      body: _photo == null ? _buildChooser() : _buildEditor(),
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
                }
                return RepaintBoundary(
                  key: _captureKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Image.file(_photo!, fit: BoxFit.contain),
                      ),
                      for (int i = 0; i < _nails.length; i++)
                        _buildNail(i, _boxSize),
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
        if (_nails.isNotEmpty) _buildPerNailHint(),
        _buildCategoryChips(),
        _buildDesignStrip(),
        _buildActions(),
      ],
    );
  }

  Widget _buildNail(int i, Size box) {
    final n = _nails[i];
    final baseW = box.width * 0.12;
    final baseH = baseW * 1.45;
    final w = baseW * n.scale;
    // Length is a style choice on top of the auto-fitted size: longer nails
    // extend the free-edge without changing the nail's width.
    final h = baseH * n.scale * n.lengthFactor;
    final selected = _selected == i;

    return Positioned(
      left: n.center.dx - w / 2,
      top: n.center.dy - h / 2,
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            // Rotate around the cuticle (bottom-centre) so the base stays
            // anchored to the finger while the tip swings, like a real nail.
            child: Transform.rotate(
              angle: n.rotation,
              alignment: Alignment.bottomCenter,
              child: NailOverlay(
                  image: designProvider(n.asset), shape: n.shape),
            ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selected = i),
              onScaleStart: (_) {
                _startScale = n.scale;
                _startRot = n.rotation;
                setState(() => _selected = i);
              },
              onScaleUpdate: (d) {
                setState(() {
                  n.center += d.focalPointDelta;
                  n.scale = (_startScale * d.scale).clamp(0.35, 4.0);
                  n.rotation = _startRot + d.rotation;
                });
              },
            ),
          ),
          if (selected)
            Positioned(
              top: -14,
              right: -14,
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

  Widget _buildPerNailHint() {
    final selected = _selected != null;
    return Container(
      width: double.infinity,
      color: selected ? const Color(0xFFEDE7F6) : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Text(
        selected
            ? 'This nail is selected — pick a design to change just this one'
            : 'Tip: tap one nail to style it on its own, or pick a design to change all',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
    final isUploads = _category == 'My Uploads';
    final designs =
        kBundledDesigns.where((d) => d.category == _category).toList();
    // In My Uploads the first tile is the "add" button; then the user's images.
    final itemCount =
        isUploads ? _customDesigns.length + 1 : designs.length;

    return Container(
      height: 92,
      color: Colors.white,
      child: itemCount == 0
          ? Center(
              child: Text('No designs in this category',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (isUploads && i == 0) return _buildUploadTile();
                final id = isUploads
                    ? _customDesigns[i - 1]
                    : designs[i].asset;
                final name = isUploads ? 'My photo' : designs[i].name;
                return _buildDesignTile(id, name);
              },
            ),
    );
  }

  Widget _buildDesignTile(String id, String name) {
    final active = _currentDesign == id;
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

/// Bottom sheet for picking a nail shape (Square/Round/Almond/Coffin/Stiletto)
/// and length (Short/Medium/Long). Changes apply live as they're tapped so the
/// customer sees them on the photo behind the sheet.
class _ShapeLengthSheet extends StatefulWidget {
  final String target;
  final NailShape initialShape;
  final double initialLength;
  final ValueChanged<NailShape> onShape;
  final ValueChanged<double> onLength;
  const _ShapeLengthSheet({
    required this.target,
    required this.initialShape,
    required this.initialLength,
    required this.onShape,
    required this.onLength,
  });

  @override
  State<_ShapeLengthSheet> createState() => _ShapeLengthSheetState();
}

class _ShapeLengthSheetState extends State<_ShapeLengthSheet> {
  static const _lengths = [
    ('Short', 0.78),
    ('Medium', 1.0),
    ('Long', 1.28),
  ];

  late NailShape _shape = widget.initialShape;
  late double _length = widget.initialLength;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00897B);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
              'Shape & length — applies to ${widget.target}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            const Text('Shape',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final s in NailShape.values)
                  GestureDetector(
                    onTap: () {
                      setState(() => _shape = s);
                      widget.onShape(s);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 78,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _shape == s ? teal : Colors.grey.shade300,
                              width: _shape == s ? 2.5 : 1,
                            ),
                          ),
                          child: NailShapePreview(shape: s),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _shape == s ? teal : Colors.grey.shade700,
                            fontWeight:
                                _shape == s ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Length',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                          color: _length == l.$2 ? teal : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          l.$1,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                _length == l.$2 ? Colors.white : Colors.black87,
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
    );
  }
}
