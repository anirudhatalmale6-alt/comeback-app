import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/models/connection_request.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  EmployeeUser? _foundEmployee;
  bool _isSearching = false;
  bool _isSending = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchByCode(String code) async {
    if (code.trim().length != 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
      _foundEmployee = null;
      _successMessage = null;
    });
    try {
      final firestoreService = context.read<FirestoreService>();
      final employee = await firestoreService.findEmployeeByCode(code.trim().toUpperCase());
      setState(() {
        _foundEmployee = employee;
        _isSearching = false;
        if (employee == null) _error = 'No employee found with that code';
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _error = 'Search failed: ${e.toString()}';
      });
    }
  }

  Future<void> _sendRequest() async {
    if (_foundEmployee == null) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final firestoreService = context.read<FirestoreService>();
      final auth = context.read<AuthService>();
      final uid = auth.getCurrentUser()!.uid;
      final owner = await firestoreService.getUser(uid) as OwnerUser;
      final request = ConnectionRequest(
        id: const Uuid().v4(),
        fromOwnerId: uid,
        toEmployeeId: _foundEmployee!.uid,
        ownerName: owner.name,
        businessName: owner.businessName,
        createdAt: DateTime.now(),
      );
      await firestoreService.sendConnectionRequest(request);
      setState(() {
        _isSending = false;
        _successMessage = 'Connection request sent!';
        _foundEmployee = null;
        _codeController.clear();
      });
    } catch (e) {
      setState(() {
        _isSending = false;
        _error = 'Failed to send request: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: const Text('Add Employee'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.keyboard), text: 'Enter Code'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEnterCodeTab(),
          _buildScanQRTab(),
        ],
      ),
    );
  }

  Widget _buildEnterCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Enter Employee Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your employee for their 6-character connection code.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSearching ? null : () => _searchByCode(_codeController.text),
            icon: _isSearching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_isSearching ? 'Searching...' : 'Search'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red[700])),
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(_successMessage!, style: const TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ],
          if (_foundEmployee != null) ...[
            const SizedBox(height: 24),
            _buildEmployeeCard(_foundEmployee!),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeUser employee) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF00897B),
              backgroundImage: employee.photoUrl != null ? NetworkImage(employee.photoUrl!) : null,
              child: employee.photoUrl == null
                  ? Text(
                      employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              employee.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(employee.phone, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSending ? null : _sendRequest,
              icon: _isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add),
              label: Text(_isSending ? 'Sending...' : 'Send Connection Request'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanQRTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Scan the QR code on your employee\'s screen.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00897B), width: 2),
            ),
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  final code = barcodes.first.rawValue!;
                  if (code.length == 6 && !_isSearching) {
                    _codeController.text = code;
                    _tabController.animateTo(0);
                    _searchByCode(code);
                  }
                }
              },
            ),
          ),
        ),
        if (_foundEmployee != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildEmployeeCard(_foundEmployee!),
          ),
      ],
    );
  }
}
