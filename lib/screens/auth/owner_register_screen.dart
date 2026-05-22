import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/storage_service.dart';

class OwnerRegisterScreen extends StatefulWidget {
  const OwnerRegisterScreen({super.key});

  @override
  State<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends State<OwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  File? _photo;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final storage = context.read<StorageService>();

      // Create Firebase Auth account
      final cred = await auth.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      final uid = cred.user!.uid;

      // Upload photo if selected
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await storage.uploadProfilePhoto(uid, _photo!);
      }

      // Create owner document in Firestore
      final owner = OwnerUser(
        uid: uid,
        name: _nameCtrl.text.trim(),
        phone: _businessPhoneCtrl.text.trim(),
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        businessName: _businessNameCtrl.text.trim(),
        businessPhone: _businessPhoneCtrl.text.trim(),
      );

      await firestore.createUser(owner);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/owner-dashboard',
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('email-already-in-use')) return 'This email is already registered.';
    if (msg.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (msg.contains('invalid-email')) return 'Please enter a valid email address.';
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        title: const Text('Owner Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF00897B),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFE0F2F1),
                              backgroundImage:
                                  _photo != null ? FileImage(_photo!) : null,
                              child: _photo == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Color(0xFF00897B),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00897B),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Business Name
                    TextFormField(
                      controller: _businessNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Business Name',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Business Phone
                    TextFormField(
                      controller: _businessPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Business Phone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Owner Name
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Owner Name',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    FilledButton(
                      onPressed: _loading ? null : _register,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
