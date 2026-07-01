import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comeback_app/models/salon_model.dart';

class ServicesScreen extends StatefulWidget {
  final String salonId;
  const ServicesScreen({super.key, required this.salonId});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _db = FirebaseFirestore.instance;

  void _addCustomService() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Service'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Service Name',
            hintText: 'e.g. Paraffin Wax',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _db.collection('services').add({
                'salonId': widget.salonId,
                'name': name,
                'enabled': true,
                'isDefault': false,
                'sortOrder': 999,
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomService,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFFFF9C4),
            child: const Text(
              'Price available in salon. Customers will see this note instead of prices.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('services')
                  .where('salonId', isEqualTo: widget.salonId)
                  .orderBy('sortOrder')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No services'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final service = SalonService.fromMap(data, id: doc.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          service.name,
                          style: TextStyle(
                            decoration: service.enabled
                                ? null
                                : TextDecoration.lineThrough,
                            color: service.enabled
                                ? null
                                : Colors.grey.shade400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: service.enabled,
                              activeColor: const Color(0xFF00897B),
                              onChanged: (v) {
                                _db
                                    .collection('services')
                                    .doc(doc.id)
                                    .update({'enabled': v});
                              },
                            ),
                            if (!service.isDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () {
                                  _db
                                      .collection('services')
                                      .doc(doc.id)
                                      .delete();
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
