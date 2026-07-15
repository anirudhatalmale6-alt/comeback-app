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

/// A design tile bundled with the app so the try-on works with no setup.
class BundledDesign {
  final String name;
  final String asset;
  const BundledDesign(this.name, this.asset);
}

const List<BundledDesign> kBundledDesigns = [
  BundledDesign('Ballet Pink', 'assets/nail_designs/ballet_pink.png'),
  BundledDesign('Classic Red', 'assets/nail_designs/classic_red.png'),
  BundledDesign('French Tip', 'assets/nail_designs/french_tip.png'),
  BundledDesign('Nude', 'assets/nail_designs/nude_beige.png'),
  BundledDesign('Gold Glitter', 'assets/nail_designs/gold_glitter.png'),
  BundledDesign('Sunset Ombre', 'assets/nail_designs/sunset_ombre.png'),
  BundledDesign('Lilac', 'assets/nail_designs/lilac.png'),
  BundledDesign('Ocean Blue', 'assets/nail_designs/ocean_blue.png'),
  BundledDesign('Polka Dots', 'assets/nail_designs/polka_dots.png'),
  BundledDesign('Midnight', 'assets/nail_designs/midnight_black.png'),
];

/// One design placed on a nail: where it sits, how big, and its angle.
class _Nail {
  Offset center;
  double scale;
  double rotation;
  String asset;
  _Nail({
    required this.center,
    required this.scale,
    required this.rotation,
    required this.asset,
  });
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
  bool _busy = false;

  final GlobalKey _captureKey = GlobalKey();
  Size _boxSize = Size.zero;

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
      _nails.clear();
      _selected = null;
      _currentDesign = null;
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
        const spots = [
          [0.30, 0.46, -0.5],
          [0.42, 0.33, -0.22],
          [0.52, 0.28, 0.0],
          [0.63, 0.33, 0.22],
          [0.74, 0.46, 0.5],
        ];
        for (final s in spots) {
          _nails.add(_Nail(
            center: Offset(_boxSize.width * s[0], _boxSize.height * s[1]),
            scale: 1.0,
            rotation: s[2].toDouble(),
            asset: asset,
          ));
        }
      } else {
        for (final n in _nails) {
          n.asset = asset;
        }
      }
    });
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

  void _reset() {
    setState(() {
      _nails.clear();
      _selected = null;
      _currentDesign = null;
    });
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
        _buildDesignStrip(),
        _buildActions(),
      ],
    );
  }

  Widget _buildNail(int i, Size box) {
    final n = _nails[i];
    final baseW = box.width * 0.12;
    final baseH = baseW * 1.5;
    final w = baseW * n.scale;
    final h = baseH * n.scale;
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
            child: Transform.rotate(
              angle: n.rotation,
              child: Opacity(
                opacity: 0.92,
                child: Image.asset(n.asset, fit: BoxFit.fill),
              ),
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
          if (_selected != null)
            TextButton.icon(
              onPressed: _removeSelected,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              label: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildDesignStrip() {
    return Container(
      height: 92,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kBundledDesigns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = kBundledDesigns[i];
          final active = _currentDesign == d.asset;
          return GestureDetector(
            onTap: () => _applyDesign(d.asset),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? const Color(0xFF00897B) : Colors.grey.shade300,
                      width: active ? 2.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(d.asset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    d.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        },
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
