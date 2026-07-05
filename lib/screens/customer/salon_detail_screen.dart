import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/models/salon_model.dart';
import 'package:comeback_app/screens/customer/book_appointment_screen.dart';

class SalonDetailScreen extends StatelessWidget {
  final String salonId;
  const SalonDetailScreen({super.key, required this.salonId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('salons').doc(salonId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  const Text('Could not load salon details'),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final salon =
            Salon.fromMap(snapshot.data!.data() as Map<String, dynamic>, id: salonId);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(salon.businessName,
                      style: const TextStyle(fontSize: 16)),
                  background: salon.profilePhotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: salon.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          color: Colors.black26,
                          colorBlendMode: BlendMode.darken,
                        )
                      : Container(
                          color: const Color(0xFF00897B),
                          child: const Center(
                            child: Icon(Icons.storefront,
                                size: 64, color: Colors.white54),
                          ),
                        ),
                ),
                actions: [
                  _FavoriteButton(salonId: salonId),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (salon.address.isNotEmpty) ...[
                        _InfoRow(Icons.location_on_outlined, salon.address),
                        const SizedBox(height: 8),
                      ],
                      if (salon.phone.isNotEmpty)
                        _InfoRow(Icons.phone_outlined, salon.phone),
                      if (salon.description != null &&
                          salon.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(salon.description!,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 24),
                      _SalonPhotos(salonId: salonId),
                      const SizedBox(height: 24),
                      _BusinessHoursSection(salonId: salonId),
                      const SizedBox(height: 24),
                      _ServicesSection(salonId: salonId),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookAppointmentScreen(
                                salonId: salonId,
                                salonName: salon.businessName,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Book Appointment'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Messaging coming soon')),
                            );
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Message Owner'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00897B)),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final String salonId;
  const _FavoriteButton({required this.salonId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final favorites = List<String>.from(
            (snapshot.data?.data() as Map<String, dynamic>?)?['favoriteSalonIds'] ?? []);
        final isFav = favorites.contains(salonId);

        return IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : Colors.white),
          onPressed: () {
            final ref =
                FirebaseFirestore.instance.collection('users').doc(uid);
            if (isFav) {
              ref.update({
                'favoriteSalonIds': FieldValue.arrayRemove([salonId])
              });
            } else {
              ref.update({
                'favoriteSalonIds': FieldValue.arrayUnion([salonId])
              });
            }
          },
        );
      },
    );
  }
}

class _SalonPhotos extends StatelessWidget {
  final String salonId;
  const _SalonPhotos({required this.salonId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('salon_photos')
          .where('salonId', isEqualTo: salonId)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final photos = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Photos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, i) {
                  final data = photos[i].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: data['photoUrl'] ?? '',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BusinessHoursSection extends StatelessWidget {
  final String salonId;
  const _BusinessHoursSection({required this.salonId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business_hours')
          .where('salonId', isEqualTo: salonId)
          .orderBy('dayOfWeek')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business Hours',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final isOpen = data['isOpen'] as bool? ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(BusinessHours.dayName(data['dayOfWeek'] as int)),
                    Text(
                      isOpen
                          ? '${data['openTime']} - ${data['closeTime']}'
                          : 'Closed',
                      style: TextStyle(
                        color:
                            isOpen ? Colors.black87 : Colors.grey.shade500,
                        fontWeight: isOpen ? FontWeight.w500 : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ServicesSection extends StatelessWidget {
  final String salonId;
  const _ServicesSection({required this.salonId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('salonId', isEqualTo: salonId)
          .where('enabled', isEqualTo: true)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final services = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Services',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: services.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return Chip(
                  label: Text(data['name'] as String,
                      style: const TextStyle(fontSize: 13)),
                  backgroundColor:
                      const Color(0xFF00897B).withValues(alpha: 0.08),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
