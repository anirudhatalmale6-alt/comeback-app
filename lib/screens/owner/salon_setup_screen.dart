import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/models/salon_model.dart';
import 'package:comeback_app/services/storage_service.dart';
import 'package:comeback_app/screens/owner/business_hours_screen.dart';
import 'package:comeback_app/screens/owner/services_screen.dart';
import 'package:comeback_app/screens/owner/salon_photos_screen.dart';

class SalonSetupScreen extends StatefulWidget {
  const SalonSetupScreen({super.key});

  @override
  State<SalonSetupScreen> createState() => _SalonSetupScreenState();
}

class _SalonSetupScreenState extends State<SalonSetupScreen> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  String? _salonId;
  String? _profilePhotoUrl;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadSalon();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalon() async {
    setState(() => _loading = true);
    try {
      final snap = await _db
          .collection('salons')
          .where('ownerUserId', isEqualTo: _uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final salon = Salon.fromMap(doc.data(), id: doc.id);
        _salonId = salon.id;
        _nameCtrl.text = salon.businessName;
        _addressCtrl.text = salon.address;
        _cityCtrl.text = salon.city ?? '';
        _zipCtrl.text = salon.zipCode ?? '';
        _phoneCtrl.text = salon.phone;
        _descCtrl.text = salon.description ?? '';
        _profilePhotoUrl = salon.profilePhotoUrl;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _changeProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final storage = context.read<StorageService>();
      final id = _salonId ?? 'new_${_uid}';
      final url = await storage.uploadSalonPhoto(
          id, 'profile.jpg', File(picked.path));

      if (_salonId != null) {
        await _db
            .collection('salons')
            .doc(_salonId)
            .update({'profilePhotoUrl': url});
      }
      setState(() => _profilePhotoUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: $e')),
      );
    }
    setState(() => _saving = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'ownerUserId': _uid,
        'businessName': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'zipCode': _zipCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'profilePhotoUrl': _profilePhotoUrl,
        'updatedAt': Timestamp.now(),
      };

      if (_salonId != null) {
        await _db.collection('salons').doc(_salonId).update(data);
      } else {
        data['createdAt'] = Timestamp.now();
        final ref = await _db.collection('salons').add(data);
        setState(() => _salonId = ref.id);
        _initDefaultServices(ref.id);
        _initDefaultHours(ref.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salon profile saved!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _saving = false);
  }

  Future<void> _initDefaultServices(String salonId) async {
    final batch = _db.batch();
    for (int i = 0; i < SalonService.defaultServices.length; i++) {
      final ref = _db.collection('services').doc();
      batch.set(ref, {
        'salonId': salonId,
        'name': SalonService.defaultServices[i],
        'enabled': true,
        'isDefault': true,
        'sortOrder': i,
      });
    }
    await batch.commit();
  }

  Future<void> _initDefaultHours(String salonId) async {
    final batch = _db.batch();
    for (int day = 1; day <= 7; day++) {
      final ref = _db.collection('business_hours').doc();
      batch.set(ref, {
        'salonId': salonId,
        'dayOfWeek': day,
        'isOpen': day <= 6,
        'openTime': '9:00 AM',
        'closeTime': day <= 5 ? '6:00 PM' : '7:00 PM',
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salon Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Salon Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _changeProfilePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: const Color(0xFFE0F2F1),
                        backgroundImage: _profilePhotoUrl != null
                            ? CachedNetworkImageProvider(_profilePhotoUrl!)
                            : null,
                        child: _saving
                            ? const CircularProgressIndicator()
                            : (_profilePhotoUrl == null
                                ? const Icon(Icons.storefront,
                                    size: 48, color: Color(0xFF00897B))
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
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Business Name',
                  prefixIcon: const Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipCtrl,
                      decoration: InputDecoration(
                        labelText: 'Zip Code',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _salonId != null ? 'Update Profile' : 'Create Salon',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              if (_salonId != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.photo_library,
                  title: 'Shop Photos',
                  subtitle: 'Upload up to 20 gallery photos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalonPhotosScreen(salonId: _salonId!),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.schedule,
                  title: 'Business Hours',
                  subtitle: 'Set weekly open/close times',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BusinessHoursScreen(salonId: _salonId!),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.list_alt,
                  title: 'Services',
                  subtitle: 'Manage your service list',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServicesScreen(salonId: _salonId!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00897B)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
