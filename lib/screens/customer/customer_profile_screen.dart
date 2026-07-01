import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/storage_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  final CustomerUser customer;
  const CustomerProfileScreen({super.key, required this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final storage = context.read<StorageService>();
      final firestore = context.read<FirestoreService>();
      final url = await storage.uploadProfilePhoto(
          widget.customer.uid, File(picked.path));
      await firestore.updateUser(widget.customer.uid, {'photoUrl': url});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _editName() {
    final ctrl = TextEditingController(text: widget.customer.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
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
              await context
                  .read<FirestoreService>()
                  .updateUser(widget.customer.uid, {'name': name});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editPhone() {
    final ctrl = TextEditingController(text: widget.customer.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Phone'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<FirestoreService>()
                  .updateUser(widget.customer.uid, {'phone': ctrl.text.trim()});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _changePhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE0F2F1),
                    backgroundImage: c.photoUrl != null
                        ? CachedNetworkImageProvider(c.photoUrl!)
                        : null,
                    child: _uploading
                        ? const CircularProgressIndicator()
                        : (c.photoUrl == null
                            ? const Icon(Icons.person,
                                size: 50, color: Color(0xFF00897B))
                            : null),
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
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _ProfileTile(
            icon: Icons.person_outline,
            label: 'Name',
            value: c.name,
            onTap: _editName,
          ),
          _ProfileTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: c.phone.isEmpty ? 'Not set' : c.phone,
            onTap: _editPhone,
          ),
          if (c.email != null)
            _ProfileTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: c.email!,
            ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.red),
            label:
                const Text('Sign Out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00897B)),
        title: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
        trailing: onTap != null
            ? IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onTap,
              )
            : null,
      ),
    );
  }
}
