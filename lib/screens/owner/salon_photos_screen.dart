import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/services/storage_service.dart';

class SalonPhotosScreen extends StatefulWidget {
  final String salonId;
  const SalonPhotosScreen({super.key, required this.salonId});

  @override
  State<SalonPhotosScreen> createState() => _SalonPhotosScreenState();
}

class _SalonPhotosScreenState extends State<SalonPhotosScreen> {
  final _db = FirebaseFirestore.instance;
  bool _uploading = false;

  Future<void> _addPhoto() async {
    final snap = await _db
        .collection('salon_photos')
        .where('salonId', isEqualTo: widget.salonId)
        .get();

    if (snap.docs.length >= 20) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 20 photos reached')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final storage = context.read<StorageService>();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await storage.uploadSalonPhoto(
          widget.salonId, fileName, File(picked.path));

      await _db.collection('salon_photos').add({
        'salonId': widget.salonId,
        'photoUrl': url,
        'sortOrder': snap.docs.length,
        'caption': '',
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
    setState(() => _uploading = false);
  }

  Future<void> _deletePhoto(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from your gallery?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.collection('salon_photos').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Photos'),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _addPhoto,
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('salon_photos')
            .where('salonId', isEqualTo: widget.salonId)
            .orderBy('sortOrder')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final photos = snapshot.data!.docs;
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No shop photos yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add up to 20 photos of your salon',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${photos.length}/20 photos',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, i) {
                    final doc = photos[i];
                    final data = doc.data() as Map<String, dynamic>;

                    return GestureDetector(
                      onLongPress: () => _deletePhoto(doc.id),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: data['photoUrl'] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
