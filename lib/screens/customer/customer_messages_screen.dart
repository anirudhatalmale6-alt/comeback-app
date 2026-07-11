import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/screens/chat/chat_screen.dart';

class CustomerMessagesScreen extends StatelessWidget {
  const CustomerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.getConversations(uid),
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
                    const Text('Could not load messages'),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!;
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open a salon and tap "Message Owner" to start a chat',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final room = rooms[i];
              final participants =
                  List<String>.from(room['participants'] ?? []);
              final otherUid = participants.firstWhere(
                (p) => p != uid,
                orElse: () => '',
              );
              final lastMessage = room['lastMessage'] as String? ?? '';
              final ts = room['lastMessageAt'] as Timestamp?;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (context, userSnap) {
                  final data =
                      userSnap.data?.data() as Map<String, dynamic>?;
                  final name = data?['businessName'] as String? ??
                      data?['name'] as String? ??
                      'Salon';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE0F2F1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ts != null
                        ? Text(
                            _formatTime(ts.toDate()),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          )
                        : null,
                    onTap: otherUid.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: otherUid,
                                  otherUserName: name,
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }
}
