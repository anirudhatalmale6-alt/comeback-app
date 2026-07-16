import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comeback_app/models/salon_model.dart';

class BusinessHoursScreen extends StatefulWidget {
  final String salonId;
  const BusinessHoursScreen({super.key, required this.salonId});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _updateHours(String docId, Map<String, dynamic> data) async {
    await _db.collection('business_hours').doc(docId).update(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Hours')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('business_hours')
            .where('salonId', isEqualTo: widget.salonId)
            .orderBy('dayOfWeek')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No hours configured'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final hours = BusinessHours.fromMap(data, id: doc.id);

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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            BusinessHours.dayName(hours.dayOfWeek),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: hours.isOpen,
                            activeColor: const Color(0xFF00897B),
                            onChanged: (v) {
                              _updateHours(doc.id, {'isOpen': v});
                            },
                          ),
                        ],
                      ),
                      if (hours.isOpen) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeDropdown(
                                label: 'Open',
                                value: hours.openTime ?? '9:00 AM',
                                onChanged: (v) {
                                  _updateHours(doc.id, {'openTime': v});
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('to'),
                            ),
                            Expanded(
                              child: _TimeDropdown(
                                label: 'Close',
                                value: hours.closeTime ?? '6:00 PM',
                                onChanged: (v) {
                                  _updateHours(doc.id, {'closeTime': v});
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Closed',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
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

class _TimeDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const _times = [
    '6:00 AM', '6:30 AM', '7:00 AM', '7:30 AM',
    '8:00 AM', '8:30 AM', '9:00 AM', '9:30 AM',
    '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM',
    '2:00 PM', '2:30 PM', '3:00 PM', '3:30 PM',
    '4:00 PM', '4:30 PM', '5:00 PM', '5:30 PM',
    '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM',
    '8:00 PM', '8:30 PM', '9:00 PM', '9:30 PM',
    '10:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _times.contains(value) ? value : _times[0],
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      isExpanded: true,
      items: _times
          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
