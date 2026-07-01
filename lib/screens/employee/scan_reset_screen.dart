import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanResetScreen extends StatefulWidget {
  const ScanResetScreen({super.key});

  @override
  State<ScanResetScreen> createState() => _ScanResetScreenState();
}

class _ScanResetScreenState extends State<ScanResetScreen> {
  final _db = FirebaseFirestore.instance;
  bool _scanned = false;
  bool _processing = false;
  String? _error;
  bool _showNewPassword = false;
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _processing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || !raw.startsWith('comeback_reset:')) continue;

      setState(() {
        _scanned = true;
        _processing = true;
      });

      final token = raw.replaceFirst('comeback_reset:', '');

      try {
        final snap = await _db
            .collection('password_reset_tokens')
            .where('token', isEqualTo: token)
            .where('usedAt', isNull: true)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          setState(() {
            _error = 'Invalid or expired code';
            _processing = false;
          });
          return;
        }

        final doc = snap.docs.first;
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (DateTime.now().isAfter(expiresAt)) {
          setState(() {
            _error = 'This code has expired. Ask your owner for a new one.';
            _processing = false;
          });
          return;
        }

        await doc.reference.update({'usedAt': Timestamp.now()});

        setState(() {
          _processing = false;
          _showNewPassword = true;
        });
      } catch (e) {
        setState(() {
          _error = 'Error: $e';
          _processing = false;
        });
      }
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (pw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(pw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showNewPassword) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create New Password')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.lock_reset, size: 48, color: Color(0xFF00897B)),
              const SizedBox(height: 16),
              const Text(
                'Enter your new password',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _processing ? null : _setNewPassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Set New Password',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Owner Reset Code')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => setState(() {
                        _error = null;
                        _scanned = false;
                      }),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: MobileScanner(onDetect: _onDetect),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black87,
                  child: const Text(
                    'Point your camera at the QR code on your owner\'s phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
    );
  }
}
