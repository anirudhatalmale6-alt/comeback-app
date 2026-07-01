import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comeback_app/models/salon_model.dart';

class EmployeeScheduleScreen extends StatefulWidget {
  final String salonId;
  final String employeeId;
  final String employeeName;

  const EmployeeScheduleScreen({
    super.key,
    required this.salonId,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeScheduleScreen> createState() =>
      _EmployeeScheduleScreenState();
}

class _EmployeeScheduleScreenState extends State<EmployeeScheduleScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _schedule = [];

  @override
  void initState() {
    super.initState();
    _loadOrCreate();
  }

  Future<void> _loadOrCreate() async {
    final snap = await _db
        .collection('employee_schedules')
        .where('salonId', isEqualTo: widget.salonId)
        .where('employeeUserId', isEqualTo: widget.employeeId)
        .orderBy('dayOfWeek')
        .get();

    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      for (int day = 1; day <= 7; day++) {
        final ref = _db.collection('employee_schedules').doc();
        batch.set(ref, {
          'salonId': widget.salonId,
          'employeeUserId': widget.employeeId,
          'dayOfWeek': day,
          'isWorking': day <= 5,
          'startTime': '9:00 AM',
          'endTime': '6:00 PM',
          'ownerApproved': true,
        });
      }
      await batch.commit();
      return _loadOrCreate();
    }

    setState(() {
      _schedule =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _loading = false;
    });
  }

  Future<void> _update(String docId, Map<String, dynamic> data) async {
    await _db.collection('employee_schedules').doc(docId).update(data);
    _loadOrCreate();
  }

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
    return Scaffold(
      appBar: AppBar(title: Text("${widget.employeeName}'s Schedule")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (context, i) {
                final s = _schedule[i];
                final isWorking = s['isWorking'] as bool? ?? false;

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
                              BusinessHours.dayName(s['dayOfWeek'] as int),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Switch(
                              value: isWorking,
                              activeColor: const Color(0xFF00897B),
                              onChanged: (v) =>
                                  _update(s['id'], {'isWorking': v}),
                            ),
                          ],
                        ),
                        if (isWorking) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _times.contains(s['startTime'])
                                      ? s['startTime'] as String
                                      : _times[0],
                                  decoration: InputDecoration(
                                    labelText: 'Start',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  isExpanded: true,
                                  items: _times
                                      .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t,
                                              style: const TextStyle(
                                                  fontSize: 14))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      _update(s['id'], {'startTime': v});
                                    }
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('to'),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _times.contains(s['endTime'])
                                      ? s['endTime'] as String
                                      : _times.last,
                                  decoration: InputDecoration(
                                    labelText: 'End',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  isExpanded: true,
                                  items: _times
                                      .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t,
                                              style: const TextStyle(
                                                  fontSize: 14))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      _update(s['id'], {'endTime': v});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Day Off',
                                style:
                                    TextStyle(color: Colors.grey.shade500)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
