import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String salonId;
  final String salonName;

  const BookAppointmentScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _db = FirebaseFirestore.instance;
  final _noteCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _hours = [];
  final Set<String> _selectedServices = {};
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final servicesSnap = await _db
        .collection('services')
        .where('salonId', isEqualTo: widget.salonId)
        .where('enabled', isEqualTo: true)
        .orderBy('sortOrder')
        .get();

    final hoursSnap = await _db
        .collection('business_hours')
        .where('salonId', isEqualTo: widget.salonId)
        .orderBy('dayOfWeek')
        .get();

    final salonDoc = await _db.collection('salons').doc(widget.salonId).get();
    final ownerId = salonDoc.data()?['ownerUserId'] as String?;

    List<Map<String, dynamic>> employees = [];
    if (ownerId != null) {
      final empSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('connectedOwnerId', isEqualTo: ownerId)
          .get();
      employees = empSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
    }

    setState(() {
      _services = servicesSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _hours = hoursSnap.docs
          .map((d) => d.data())
          .toList();
      _employees = employees;
      _loading = false;
    });
  }

  bool _isDayOpen(DateTime date) {
    final dow = date.weekday; // 1=Mon, 7=Sun
    for (final h in _hours) {
      if (h['dayOfWeek'] == dow && h['isOpen'] == true) return true;
    }
    return false;
  }

  List<String> _getTimesForDay(DateTime date) {
    final dow = date.weekday;
    for (final h in _hours) {
      if (h['dayOfWeek'] == dow && h['isOpen'] == true) {
        final open = h['openTime'] as String? ?? '9:00 AM';
        final close = h['closeTime'] as String? ?? '6:00 PM';
        return _generateTimes(open, close);
      }
    }
    return [];
  }

  List<String> _generateTimes(String open, String close) {
    const allTimes = [
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
    final openIdx = allTimes.indexOf(open);
    final closeIdx = allTimes.indexOf(close);
    if (openIdx < 0 || closeIdx < 0) return allTimes;
    return allTimes.sublist(openIdx, closeIdx);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      selectableDayPredicate: _isDayOpen,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      await _db.collection('appointments').add({
        'salonId': widget.salonId,
        'customerUserId': uid,
        'assignedEmployeeUserId': _selectedEmployeeId,
        'services': _selectedServices.toList(),
        'otherText': _otherCtrl.text.trim().isEmpty
            ? null
            : _otherCtrl.text.trim(),
        'date': dateStr,
        'time': _selectedTime,
        'customerNote': _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
        'attachedPhotoIds': [],
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Book at ${widget.salonName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final availableTimes =
        _selectedDate != null ? _getTimesForDay(_selectedDate!) : <String>[];

    return Scaffold(
      appBar: AppBar(title: Text('Book at ${widget.salonName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Services',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _services.map((s) {
                final name = s['name'] as String;
                final selected = _selectedServices.contains(name);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  selectedColor: const Color(0xFF00897B).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF00897B),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedServices.add(name);
                      } else {
                        _selectedServices.remove(name);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedServices.contains('Other')) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherCtrl,
                decoration: InputDecoration(
                  labelText: 'Describe your service request',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Price available in salon.',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('Select Date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate != null
                    ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
                    : 'Choose a date',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_selectedDate != null) ...[
              const SizedBox(height: 20),
              const Text('Select Time',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableTimes.map((t) {
                  final selected = _selectedTime == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: selected,
                    selectedColor:
                        const Color(0xFF00897B).withValues(alpha: 0.2),
                    onSelected: (v) {
                      setState(() => _selectedTime = v ? t : null);
                    },
                  );
                }).toList(),
              ),
            ],

            if (_employees.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Employee Preference (optional)',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _selectedEmployeeId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Any Available Employee'),
                  ),
                  ..._employees.map((e) => DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(e['name'] as String? ?? 'Employee'),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
              ),
            ],

            const SizedBox(height: 20),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Note to owner (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Booking Request',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
