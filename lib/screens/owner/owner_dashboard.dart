import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/models/page_alert.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/screens/chat/chat_screen.dart';
import 'package:comeback_app/screens/chat/group_chat_screen.dart';
import 'package:comeback_app/screens/owner/add_employee_screen.dart';
import 'package:comeback_app/screens/owner/owner_profile_screen.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _currentIndex = 0;
  final Map<String, String> _activePages = {};

  @override
  void initState() {
    super.initState();
    _listenForAcknowledgedPages();
  }

  void _listenForAcknowledgedPages() {
    final auth = context.read<AuthService>();
    final uid = auth.getCurrentUser()?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('page_alerts')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: AlertStatus.acknowledged.name)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final alert = PageAlert.fromMap(change.doc.data()!, id: change.doc.id);
          _activePages.remove(alert.employeeId);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Employee confirmed'),
                backgroundColor: Color(0xFF00897B),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _pageEmployee(String employeeId, FirestoreService firestoreService) async {
    final auth = context.read<AuthService>();
    final uid = auth.getCurrentUser()!.uid;
    final alertId = const Uuid().v4();
    final alert = PageAlert(
      id: alertId,
      ownerId: uid,
      employeeId: employeeId,
      status: AlertStatus.active,
      createdAt: DateTime.now(),
    );
    await firestoreService.createPageAlert(alert);
    setState(() => _activePages[employeeId] = alertId);
  }

  Future<void> _cancelPage(String employeeId, FirestoreService firestoreService) async {
    final alertId = _activePages[employeeId];
    if (alertId == null) return;
    await firestoreService.cancelPageAlert(alertId);
    setState(() => _activePages.remove(employeeId));
  }

  String get _uid => context.read<AuthService>().getCurrentUser()!.uid;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildEmployeeList(),
      GroupChatScreen(ownerId: _uid),
      const OwnerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF00897B).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFF00897B)),
            label: 'Employees',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00897B)),
            label: 'Group Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF00897B)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    final auth = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final uid = auth.getCurrentUser()!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const Text('Come Back');
            final owner = OwnerUser.fromMap(snapshot.data!.data() as Map<String, dynamic>);
            return Text(owner.businessName);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => setState(() => _currentIndex = 2),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, ownerSnapshot) {
          if (ownerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
          }
          if (!ownerSnapshot.hasData || !ownerSnapshot.data!.exists) {
            return const Center(child: Text('Error loading profile'));
          }

          final owner = OwnerUser.fromMap(ownerSnapshot.data!.data() as Map<String, dynamic>);
          final employeeIds = owner.employeeIds;

          if (employeeIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No employees connected yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: employeeIds)
                .snapshots(),
            builder: (context, empSnapshot) {
              if (empSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
              }
              if (!empSnapshot.hasData || empSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No employees found'));
              }

              final employees = empSnapshot.data!.docs
                  .map((doc) => EmployeeUser.fromMap(doc.data() as Map<String, dynamic>))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  final isPaging = _activePages.containsKey(emp.uid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF00897B),
                        backgroundImage: emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
                        child: emp.photoUrl == null
                            ? Text(
                                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        emp.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00897B)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: emp.uid,
                                  otherUserName: emp.name,
                                ),
                              ),
                            ),
                          ),
                          isPaging
                              ? IconButton(
                                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                                  onPressed: () => _cancelPage(emp.uid, firestoreService),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.notifications_active, color: Color(0xFF00897B)),
                                  onPressed: () => _pageEmployee(emp.uid, firestoreService),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
