import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/services/storage_service.dart';
import 'package:comeback_app/screens/auth/auth_wrapper.dart';

class EmployeeProfileScreen extends StatelessWidget {
  final EmployeeUser employee;
  const EmployeeProfileScreen({super.key, required this.employee});

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null) return;

    try {
      final storage = context.read<StorageService>();
      final firestore = context.read<FirestoreService>();
      final photoUrl = await storage.uploadProfilePhoto(employee.uid, File(picked.path));
      await firestore.updateUser(employee.uid, {'photoUrl': photoUrl});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload photo: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showStatusPicker(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Set Your Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...EmployeeStatus.values.map((status) => ListTile(
              leading: Icon(
                _statusIcon(status),
                color: _statusColor(status),
              ),
              title: Text(status.displayName),
              trailing: employee.status == status
                  ? const Icon(Icons.check_circle, color: Color(0xFF00897B))
                  : null,
              onTap: () {
                firestore.updateEmployeeStatus(employee.uid, status.name);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Avatar with camera button
            GestureDetector(
              onTap: () => _pickAndUploadPhoto(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF00897B),
                    backgroundImage: employee.photoUrl != null
                        ? NetworkImage(employee.photoUrl!)
                        : null,
                    child: employee.photoUrl == null
                        ? Text(
                            employee.name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              employee.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              employee.phone,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Status selector
            GestureDetector(
              onTap: () => _showStatusPicker(context),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(_statusIcon(employee.status), color: _statusColor(employee.status)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            Text(
                              employee.status.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(employee.status),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Connection code card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Connection Code',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      employee.connectionCode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: employee.connectionCode,
                      version: QrVersions.auto,
                      size: 150,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: Color(0xFF00897B),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (employee.isConnected) _ConnectedSalonCard(employee: employee),
            const SizedBox(height: 24),
            if (employee.isConnected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDisconnect(context),
                  icon: const Icon(Icons.link_off, color: Colors.red),
                  label: const Text('Disconnect from Salon'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (employee.isConnected) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
          'You will no longer receive page alerts from this salon. '
          'You can reconnect later with a new request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final firestore = context.read<FirestoreService>();
              await firestore.disconnect(
                employee.connectedOwnerId!,
                employee.uid,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthService>();
    await auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (_) => false,
      );
    }
  }

  static IconData _statusIcon(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.available:
        return Icons.check_circle;
      case EmployeeStatus.busy:
        return Icons.access_time;
      case EmployeeStatus.dayOff:
        return Icons.wb_sunny;
      case EmployeeStatus.doNotDisturb:
        return Icons.do_not_disturb_on;
    }
  }

  static Color _statusColor(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.available:
        return Colors.green;
      case EmployeeStatus.busy:
        return Colors.orange;
      case EmployeeStatus.dayOff:
        return Colors.blue;
      case EmployeeStatus.doNotDisturb:
        return Colors.red;
    }
  }
}

class _ConnectedSalonCard extends StatelessWidget {
  final EmployeeUser employee;
  const _ConnectedSalonCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<AppUser?>(
      stream: firestore.userStream(employee.connectedOwnerId!),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final owner = snap.data! as OwnerUser;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF00897B),
              backgroundImage: owner.photoUrl != null
                  ? NetworkImage(owner.photoUrl!)
                  : null,
              child: owner.photoUrl == null
                  ? Text(
                      owner.businessName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              owner.businessName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(owner.name),
            trailing: const Icon(
              Icons.check_circle,
              color: Color(0xFF00897B),
            ),
          ),
        );
      },
    );
  }
}
