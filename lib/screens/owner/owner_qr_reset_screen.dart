import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:comeback_app/models/user_model.dart';

class OwnerQrResetScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const OwnerQrResetScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<OwnerQrResetScreen> createState() => _OwnerQrResetScreenState();
}

class _OwnerQrResetScreenState extends State<OwnerQrResetScreen> {
  final _db = FirebaseFirestore.instance;
  final _passwordCtrl = TextEditingController();
  bool _verified = false;
  String? _resetToken;
  DateTime? _expiresAt;
  bool _loading = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      setState(() => _verified = true);
      _generateToken();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _generateToken() async {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final token = base64Url.encode(bytes);
    final expires = DateTime.now().add(const Duration(minutes: 2));

    await _db.collection('password_reset_tokens').add({
      'employeeUserId': widget.employeeId,
      'ownerUserId': _uid,
      'tokenHash': token.hashCode.toString(),
      'token': token,
      'expiresAt': Timestamp.fromDate(expires),
      'usedAt': null,
      'createdAt': Timestamp.now(),
    });

    setState(() {
      _resetToken = token;
      _expiresAt = expires;
    });

    Future.delayed(const Duration(minutes: 2), () {
      if (mounted) {
        setState(() {
          _resetToken = null;
          _expiresAt = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset ${widget.employeeName}\'s Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_verified) ...[
              const Icon(Icons.security, size: 48, color: Color(0xFF00897B)),
              const SizedBox(height: 16),
              const Text(
                'Verify your identity to generate a reset code',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Your Owner Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Generate Code',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_resetToken != null) ...[
              const Icon(Icons.qr_code_2,
                  size: 48, color: Color(0xFF00897B)),
              const SizedBox(height: 16),
              Text(
                'Show this QR to ${widget.employeeName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: QrImageView(
                    data: 'comeback_reset:$_resetToken',
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF00897B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Expires in 2 minutes. One-time use only.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _generateToken,
                child: const Text('Generate New Code'),
              ),
            ] else ...[
              const Icon(Icons.timer_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Code expired', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _generateToken,
                child: const Text('Generate New Code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
