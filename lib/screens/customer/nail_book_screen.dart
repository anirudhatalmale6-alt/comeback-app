import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comeback_app/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The customer's saved nail looks, presented as a book rather than a grid.
///
/// Same data as before — the `customer_nail_photos` collection, holding both
/// photos taken in the salon and looks saved out of the Virtual Try-On. Only
/// the presentation changed: a grid of square cards says "camera roll", and
/// what a customer actually keeps is closer to a lookbook she leafs through and
/// shows to her technician.
///
/// There is deliberately ONE screen for this collection. An earlier instinct
/// was to leave the old grid in place and add the book beside it, which would
/// have meant two routes to the same noun and two things to keep in step.
///
/// The pieces below ([NailBookCover], [NailBookPage], [NailBookPlate]) take
/// plain [ImageProvider]s rather than reaching for the network themselves, so
/// the look of the book can be rendered and checked without Firestore.
class NailBookScreen extends StatefulWidget {
  /// The customer's name, for the cover. Taken from the signed-in
  /// [CustomerUser] rather than from Firebase Auth's `displayName` — this app
  /// never calls `updateDisplayName`, so that field is always null and the
  /// cover would silently have gone out unsigned.
  final String customerName;

  const NailBookScreen({super.key, this.customerName = ''});

  @override
  State<NailBookScreen> createState() => _NailBookScreenState();
}

/// One saved look, as the book needs it.
class NailLook {
  final ImageProvider image;
  final String note;
  final DateTime? date;

  /// Looks saved out of the Try-On are marked so the book can say where they
  /// came from, instead of printing "Virtual Try-On" as if the customer had
  /// typed it as a note.
  final bool fromTryOn;

  const NailLook({
    required this.image,
    this.note = '',
    this.date,
    this.fromTryOn = false,
  });
}

/// Paper, ink and thread. Pulled out so the cover, the pages and the plates
/// cannot drift apart from one another.
class _Book {
  static const paper = Color(0xFFFBF6EF);
  static const paperEdge = Color(0xFFF1E8DC);
  static const desk = Color(0xFFEFE7DE);
  static const ink = Color(0xFF3B3330);
  static const inkSoft = Color(0xFF8A7B74);
  static const rose = Color(0xFFC2607F);
  static const gilt = Color(0xFFBE9A5E);
  static const serif = 'NailBookSerif';
}

class _NailBookScreenState extends State<NailBookScreen> {
  final _db = FirebaseFirestore.instance;
  final _controller = PageController(viewportFraction: 0.92);
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a note'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: noteCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Colour, shape, design notes…',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Skip')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final url = await context.read<StorageService>().uploadFile(
            'customer_nails/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
            File(picked.path),
          );
      await _db.collection('customer_nail_photos').add({
        'customerUserId': _uid,
        'photoUrl': url,
        'note': note,
        'createdAt': Timestamp.now(),
      });
      _snack('Added to your nail book 💅');
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Book.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _Book.inkSoft.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: _Book.rose),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: _Book.rose),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _openLook(NailLook look) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LookViewer(look: look),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Book.desk,
      appBar: AppBar(
        backgroundColor: _Book.desk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _Book.ink,
        title: const Text(
          'My Nail Book',
          style: TextStyle(
            fontFamily: _Book.serif,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add a look',
            icon: const Icon(Icons.add_rounded),
            onPressed: _busy ? null : _showAddOptions,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('customer_nail_photos')
            .where('customerUserId', isEqualTo: _uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline_rounded,
              title: 'Could not open your book',
              body: 'Check your connection and try again.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _Book.rose),
            );
          }

          final looks = snapshot.data!.docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            final ts = m['createdAt'];
            return NailLook(
              image: CachedNetworkImageProvider((m['photoUrl'] ?? '') as String),
              note: (m['note'] ?? '') as String,
              date: ts is Timestamp ? ts.toDate() : null,
              fromTryOn: m['source'] == 'tryon',
            );
          }).toList();

          // A page holds two looks. The cover is page 0, so an empty book is
          // still a book: a cover and one page explaining how to fill it.
          final int sheets = NailBookPage.sheetsFor(looks.length);
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: sheets + 1,
                  itemBuilder: (context, i) {
                    final child = i == 0
                        ? NailBookCover(
                            name: widget.customerName
                                .trim()
                                .split(RegExp(r'\s+'))
                                .first,
                            count: looks.length,
                          )
                        : NailBookPage(
                            looks: looks
                                .skip((i - 1) * NailBookPage.perPage)
                                .take(NailBookPage.perPage)
                                .toList(),
                            pageNumber: i,
                            onTapLook: _openLook,
                            onAddFirst: _showAddOptions,
                          );
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                      child: child,
                    );
                  },
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: _Book.rose),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Swipe to turn the page',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.4,
                  color: _Book.inkSoft.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

/// The shared look of a sheet of the book: warm paper, a bound left edge with
/// its stitching, and the shadow that lifts it off the desk. The bound edge is
/// what does most of the work — a plain rounded rectangle reads as a card, and
/// the same rectangle with one squared-off, shaded edge reads as a page.
class _Sheet extends StatelessWidget {
  final Widget child;
  final Color colour;
  const _Sheet({required this.child, this.colour = _Book.paper});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          bottomLeft: Radius.circular(5),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: _Book.ink.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(2, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          // The gutter: the page curving down into the binding.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _Book.ink.withValues(alpha: 0.16),
                    _Book.ink.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Stitching along the binding.
          Positioned(
            left: 9,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  9,
                  (i) => Container(
                    width: 1.6,
                    height: 11,
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _Book.ink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The front cover.
class NailBookCover extends StatelessWidget {
  final String name;
  final int count;
  const NailBookCover({super.key, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      colour: const Color(0xFF9E4E6B),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB4607E), Color(0xFF8C4460)],
                ),
              ),
            ),
          ),
          // A double gilt rule, the way a bound book is tooled. Inset far enough
          // that the binding shadow does not cut through it.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 22, 22, 22),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _Book.gilt.withValues(alpha: 0.75), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _Book.gilt.withValues(alpha: 0.45), width: 0.8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.spa_outlined,
                              size: 40,
                              color: _Book.gilt.withValues(alpha: 0.9)),
                          const SizedBox(height: 18),
                          const Text(
                            'My Nail Book',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _Book.serif,
                              fontSize: 27,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF6EAD9),
                              letterSpacing: 0.6,
                            ),
                          ),
                          if (name.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: 44,
                              height: 1,
                              color: _Book.gilt.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: TextStyle(
                                fontFamily: _Book.serif,
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFF6EAD9)
                                    .withValues(alpha: 0.85),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Text(
                            count == 0
                                ? 'No looks yet'
                                : count == 1
                                    ? '1 look'
                                    : '$count looks',
                            style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 1.6,
                              color: const Color(0xFFF6EAD9)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One page of the book: up to [perPage] looks mounted on paper.
class NailBookPage extends StatelessWidget {
  static const int perPage = 2;

  /// How many paper pages [looks] fills. An empty book still has one page —
  /// the invitation to start it — so this never returns 0.
  ///
  /// Worth a named function and a test rather than an expression buried in a
  /// builder: an off-by-one here does not crash, it just quietly drops the last
  /// look off the end of the book, which nobody would report as a bug.
  static int sheetsFor(int looks) =>
      looks <= 0 ? 1 : (looks + perPage - 1) ~/ perPage;

  final List<NailLook> looks;
  final int pageNumber;
  final ValueChanged<NailLook>? onTapLook;
  final VoidCallback? onAddFirst;

  const NailBookPage({
    super.key,
    required this.looks,
    required this.pageNumber,
    this.onTapLook,
    this.onAddFirst,
  });

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 18, 20, 12),
        child: Column(
          children: [
            Expanded(
              child: looks.isEmpty
                  ? _EmptyPage(onAdd: onAddFirst)
                  : Column(
                      children: [
                        for (int i = 0; i < looks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          Expanded(
                            child: NailBookPlate(
                              look: looks[i],
                              // Alternating hand-mounted tilt. Tiny on purpose:
                              // past about a degree it stops reading as a photo
                              // stuck into an album and starts looking broken.
                              tilt: i.isEven ? -0.009 : 0.009,
                              onTap: onTapLook == null
                                  ? null
                                  : () => onTapLook!(looks[i]),
                            ),
                          ),
                        ],
                        // One look on the last page should sit at the top of
                        // the page like a real album, not stretch to fill it.
                        if (looks.length < perPage) const Spacer(),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pageNumber',
              style: TextStyle(
                fontFamily: _Book.serif,
                fontSize: 12,
                color: _Book.inkSoft.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single look mounted on the page: the photo in a cream mount with a hairline
/// border, the customer's note written under it, and the date it was saved.
class NailBookPlate extends StatelessWidget {
  final NailLook look;
  final double tilt;
  final VoidCallback? onTap;

  const NailBookPlate({
    super.key,
    required this.look,
    this.tilt = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String caption = look.note.trim().isNotEmpty
        ? look.note.trim()
        : (look.fromTryOn ? 'Designed in Try-On' : 'Untitled look');

    return Transform.rotate(
      angle: tilt,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _Book.paperEdge),
                  boxShadow: [
                    BoxShadow(
                      color: _Book.ink.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRect(
                  child: Image(image: look.image, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _Book.serif,
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: _Book.ink,
                    ),
                  ),
                ),
                if (look.date != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMM yyyy').format(look.date!),
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                      color: _Book.inkSoft.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptyPage({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 42, color: _Book.inkSoft.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Your first page',
            style: TextStyle(
              fontFamily: _Book.serif,
              fontSize: 19,
              color: _Book.ink,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Save a look from the Try-On, or add a photo from your '
              'last appointment, and it will be mounted here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _Book.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (onAdd != null)
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Book.rose,
                side: BorderSide(color: _Book.rose.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              label: const Text('Add a photo'),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Message({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _Book.inkSoft),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontFamily: _Book.serif, fontSize: 17, color: _Book.ink)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _Book.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// One look, full screen, for when the customer wants to actually look at it or
/// show it to the technician.
class _LookViewer extends StatelessWidget {
  final NailLook look;
  const _LookViewer({required this.look});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17120F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(image: look.image, fit: BoxFit.contain),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
            child: Column(
              children: [
                if (look.note.trim().isNotEmpty)
                  Text(
                    look.note.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: _Book.serif,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                if (look.date != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('d MMMM yyyy').format(look.date!),
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
