import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/screens/customer/salon_detail_screen.dart';

class FavoriteSalonsScreen extends StatelessWidget {
  const FavoriteSalonsScreen({super.key});

  Future<List<QueryDocumentSnapshot>> _fetchSalons(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = FirebaseFirestore.instance;
    // whereIn supports up to 10 ids per query, so chunk if needed.
    final List<QueryDocumentSnapshot> out = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await db
          .collection('salons')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      out.addAll(snap.docs);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) {
            return const Center(child: Text('Could not load favorites'));
          }
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = userSnap.data!.data() as Map<String, dynamic>?;
          final ids = List<String>.from(data?['favoriteSalonIds'] ?? []);

          if (ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart on a salon to save it here',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchSalons(ids),
            builder: (context, salonSnap) {
              if (salonSnap.hasError) {
                return const Center(child: Text('Could not load favorites'));
              }
              if (!salonSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final salons = salonSnap.data!;
              return ListView.builder(
                itemCount: salons.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, i) {
                  final salon = salons[i].data() as Map<String, dynamic>;
                  final salonId = salons[i].id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SalonDetailScreen(salonId: salonId),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: salon['profilePhotoUrl'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: salon['profilePhotoUrl'],
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFE0F2F1),
                                      child: const Icon(Icons.storefront,
                                          color: Color(0xFF00897B)),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    salon['businessName'] ?? 'Salon',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (salon['address'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      salon['address'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
