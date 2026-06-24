import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/services/storage_service.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  Future<void> _pickAndUploadPhoto(BuildContext context, String uid) async {
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
      final photoUrl = await storage.uploadProfilePhoto(uid, File(picked.path));
      await firestore.updateUser(uid, {'photoUrl': photoUrl});
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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.getCurrentUser()!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile not found'));
          }

          final owner = OwnerUser.fromMap(snapshot.data!.data() as Map<String, dynamic>);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProfileHeader(context, owner),
                const SizedBox(height: 20),
                _buildInfoCard(owner),
                const SizedBox(height: 20),
                _buildEmployeesSection(context, owner),
                const SizedBox(height: 32),
                _buildSignOutButton(context, auth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, OwnerUser owner) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickAndUploadPhoto(context, owner.uid),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF00897B),
                    backgroundImage: owner.photoUrl != null ? NetworkImage(owner.photoUrl!) : null,
                    child: owner.photoUrl == null
                        ? Text(
                            owner.name.isNotEmpty ? owner.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
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
            const SizedBox(height: 12),
            Text(owner.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(owner.businessName, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, owner),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00897B),
                side: const BorderSide(color: Color(0xFF00897B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(OwnerUser owner) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(Icons.business, 'Business', owner.businessName),
            const Divider(),
            _infoRow(Icons.phone, 'Business Phone', owner.businessPhone),
            const Divider(),
            _infoRow(Icons.person, 'Owner Name', owner.name),
            const Divider(),
            _infoRow(Icons.people, 'Connected Employees', '${owner.employeeIds.length}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00897B)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesSection(BuildContext context, OwnerUser owner) {
    if (owner.employeeIds.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No connected employees', style: TextStyle(color: Colors.grey[500])),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Connected Employees',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: owner.employeeIds)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00897B))),
                );
              }

              final employees = snapshot.data!.docs
                  .map((doc) => EmployeeUser.fromMap(doc.data() as Map<String, dynamic>))
                  .toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: employees.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF00897B),
                          backgroundImage: emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
                          child: emp.photoUrl == null
                              ? Text(
                                  emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _statusColor(emp.status),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(emp.status.displayName, style: TextStyle(color: _statusColor(emp.status), fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      onPressed: () => _confirmDisconnect(context, owner.uid, emp),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, String ownerId, EmployeeUser employee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Employee'),
        content: Text('Remove ${employee.name} from your team? They will no longer receive pages.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FirestoreService>().disconnect(ownerId, employee.uid);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, OwnerUser owner) {
    final nameController = TextEditingController(text: owner.name);
    final businessNameController = TextEditingController(text: owner.businessName);
    final businessPhoneController = TextEditingController(text: owner.businessPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Business Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FirestoreService>().updateUser(owner.uid, {
                    'name': nameController.text.trim(),
                    'businessName': businessNameController.text.trim(),
                    'businessPhone': businessPhoneController.text.trim(),
                  });
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, AuthService auth) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  auth.signOut();
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Color _statusColor(EmployeeStatus status) {
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
