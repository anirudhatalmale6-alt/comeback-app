import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:comeback_app/models/salon_model.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  void _requestChange(Map<String, dynamic> schedule) {
    final noteCtrl = TextEditingController();
    String requestType = 'day_off';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request Schedule Change'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                BusinessHours.dayName(schedule['dayOfWeek'] as int),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day_off', label: Text('Day Off')),
                  ButtonSegment(
                      value: 'change_hours', label: Text('Change Hours')),
                ],
                selected: {requestType},
                onSelectionChanged: (s) {
                  setDialogState(() => requestType = s.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Reason for request...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _db.collection('schedule_requests').add({
                  'salonId': schedule['salonId'],
                  'employeeUserId': _uid,
                  'requestType': requestType,
                  'requestedDate': null,
                  'requestedHours': null,
                  'dayOfWeek': schedule['dayOfWeek'],
                  'note': noteCtrl.text.trim(),
                  'status': 'pending',
                  'ownerResponse': null,
                  'createdAt': Timestamp.now(),
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request sent to owner'),
                    backgroundColor: Color(0xFF00897B),
                  ),
                );
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('employee_schedules')
            .where('employeeUserId', isEqualTo: _uid)
            .orderBy('dayOfWeek')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No schedule set yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your owner will set your work schedule',
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
              data['id'] = docs[i].id;
              final isWorking = data['isWorking'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    BusinessHours.dayName(data['dayOfWeek'] as int),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isWorking
                        ? '${data['startTime']} - ${data['endTime']}'
                        : 'Day Off',
                    style: TextStyle(
                      color: isWorking
                          ? const Color(0xFF00897B)
                          : Colors.grey.shade500,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _requestChange(data),
                    child: const Text('Request Change'),
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
