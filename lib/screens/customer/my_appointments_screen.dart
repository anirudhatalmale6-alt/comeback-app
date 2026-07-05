import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('customerUserId', isEqualTo: _uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    const Text('Could not load appointments',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No appointments yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book an appointment at your favorite salon',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final services =
                  (data['services'] as List<dynamic>?)?.join(', ') ?? '';
              final status = data['status'] as String? ?? 'pending';

              Color badgeBg;
              Color badgeFg;
              switch (status) {
                case 'pending':
                  badgeBg = Colors.orange.shade50;
                  badgeFg = Colors.orange.shade700;
                  break;
                case 'confirmed':
                  badgeBg = Colors.green.shade50;
                  badgeFg = Colors.green.shade700;
                  break;
                case 'denied':
                  badgeBg = Colors.red.shade50;
                  badgeFg = Colors.red.shade700;
                  break;
                case 'suggested_new_time':
                  badgeBg = Colors.blue.shade50;
                  badgeFg = Colors.blue.shade700;
                  break;
                default:
                  badgeBg = Colors.grey.shade100;
                  badgeFg = Colors.grey.shade600;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF00897B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${data['date']} at ${data['time']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (services.isNotEmpty)
                        Text(services,
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                      if (status == 'suggested_new_time') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'New time: ${data['suggestedDate'] ?? ''} at ${data['suggestedTime'] ?? ''}',
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
