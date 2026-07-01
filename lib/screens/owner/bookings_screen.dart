import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late TabController _tabCtrl;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSalonId();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalonId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await _db
        .collection('salons')
        .where('ownerUserId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      setState(() => _salonId = snap.docs.first.id);
    }
  }

  Future<void> _updateStatus(String docId, String status,
      {Map<String, dynamic>? extra}) async {
    final data = {'status': status, ...?extra};
    await _db.collection('appointments').doc(docId).update(data);
  }

  void _showActions(BuildContext ctx, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Approve'),
              onTap: () {
                Navigator.pop(bCtx);
                _updateStatus(docId, 'confirmed');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Deny'),
              onTap: () {
                Navigator.pop(bCtx);
                _updateStatus(docId, 'denied');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('Suggest New Time'),
              onTap: () {
                Navigator.pop(bCtx);
                _showSuggestTime(docId);
              },
            ),
            if (data['status'] == 'confirmed')
              ListTile(
                leading: const Icon(Icons.login, color: Colors.blue),
                title: const Text('Mark Checked In'),
                onTap: () {
                  Navigator.pop(bCtx);
                  _updateStatus(docId, 'checked_in');
                },
              ),
            if (data['status'] == 'checked_in')
              ListTile(
                leading:
                    const Icon(Icons.done_all, color: Colors.green),
                title: const Text('Mark Completed'),
                onTap: () {
                  Navigator.pop(bCtx);
                  _updateStatus(docId, 'completed');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_off, color: Colors.grey),
              title: const Text('Mark No-Show'),
              onTap: () {
                Navigator.pop(bCtx);
                _updateStatus(docId, 'no_show');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSuggestTime(String docId) {
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suggest New Time'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(labelText: 'New Date'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(labelText: 'New Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(docId, 'suggested_new_time', extra: {
                'suggestedDate': dateCtrl.text.trim(),
                'suggestedTime': timeCtrl.text.trim(),
              });
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Today'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: _salonId == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _BookingList(
                  salonId: _salonId!,
                  statusFilter: ['pending'],
                  onAction: _showActions,
                ),
                _BookingList(
                  salonId: _salonId!,
                  statusFilter: ['confirmed', 'checked_in'],
                  onAction: _showActions,
                ),
                _BookingList(
                  salonId: _salonId!,
                  statusFilter: null,
                  onAction: _showActions,
                ),
              ],
            ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final String salonId;
  final List<String>? statusFilter;
  final void Function(BuildContext, String, Map<String, dynamic>) onAction;

  const _BookingList({
    required this.salonId,
    this.statusFilter,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('salonId', isEqualTo: salonId);

    if (statusFilter != null) {
      query = query.where('status', whereIn: statusFilter);
    }
    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No bookings',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final services =
                (data['services'] as List<dynamic>?)?.join(', ') ?? '';
            final status = data['status'] as String? ?? 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => onAction(context, doc.id, data),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${data['date']} at ${data['time']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Services: $services',
                          style: TextStyle(color: Colors.grey.shade600)),
                      if (data['customerNote'] != null &&
                          (data['customerNote'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Note: ${data['customerNote']}',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 'confirmed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'denied':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      case 'completed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
