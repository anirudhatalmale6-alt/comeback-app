import 'dart:async';
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
import 'package:comeback_app/screens/owner/salon_setup_screen.dart';
import 'package:comeback_app/screens/owner/bookings_screen.dart';
import 'package:comeback_app/widgets/tryon_banner.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _currentIndex = 0;
  final Map<String, _PageState> _pageStates = {};
  StreamSubscription? _alertSub;

  @override
  void initState() {
    super.initState();
    _listenForPageUpdates();
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  void _listenForPageUpdates() {
    final auth = context.read<AuthService>();
    final uid = auth.getCurrentUser()?.uid;
    if (uid == null) return;

    _alertSub = FirebaseFirestore.instance
        .collection('page_alerts')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final alert = PageAlert.fromMap(data, id: change.doc.id);
        final empId = alert.employeeId;

        if (alert.status == AlertStatus.active) {
          _pageStates[empId] = _PageState(alertId: alert.id, status: _PagingStatus.active);
        } else if (alert.status == AlertStatus.acknowledged) {
          if (_pageStates.containsKey(empId) && _pageStates[empId]!.alertId == alert.id) {
            _pageStates[empId] = _PageState(alertId: alert.id, status: _PagingStatus.acknowledged);
          }
        } else if (alert.status == AlertStatus.cancelled) {
          if (_pageStates.containsKey(empId) && _pageStates[empId]!.alertId == alert.id) {
            _pageStates.remove(empId);
          }
        }
      }
      setState(() {});
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
    setState(() => _pageStates[employeeId] = _PageState(alertId: alertId, status: _PagingStatus.active));
  }

  Future<void> _cancelPage(String employeeId, FirestoreService firestoreService) async {
    final state = _pageStates[employeeId];
    if (state == null) return;
    await firestoreService.cancelPageAlert(state.alertId);
    setState(() => _pageStates.remove(employeeId));
  }

  String get _uid => context.read<AuthService>().getCurrentUser()!.uid;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildEmployeeList(),
      const OwnerBookingsScreen(),
      GroupChatScreen(ownerId: _uid),
      const SalonSetupScreen(),
      const OwnerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF00897B).withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFF00897B)),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF00897B)),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00897B)),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF00897B)),
            label: 'Salon',
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
            onPressed: () => setState(() => _currentIndex = 4),
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TryOnBanner(
              subtitle: 'Preview looks and recommend them to clients',
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
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
                  final pageState = _pageStates[emp.uid];
                  final canPage = emp.status.canBePaged;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // Profile photo
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF00897B),
                                backgroundImage: emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
                                child: emp.photoUrl == null
                                    ? Text(
                                        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _statusColor(emp.status),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Name + Status
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  emp.status.displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _statusColor(emp.status),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chat button
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00897B), size: 22),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: emp.uid,
                                  otherUserName: emp.name,
                                ),
                              ),
                            ),
                            tooltip: 'Chat',
                          ),
                          // Page button with status
                          _buildPageButton(emp, pageState, canPage, firestoreService),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(EmployeeUser emp, _PageState? pageState, bool canPage, FirestoreService fs) {
    if (pageState != null && pageState.status == _PagingStatus.acknowledged) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 4),
                Text('Responded', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Color(0xFF00897B), size: 22),
            onPressed: () {
              _pageStates.remove(emp.uid);
              _pageEmployee(emp.uid, fs);
            },
            tooltip: 'Page again',
          ),
        ],
      );
    }

    if (pageState != null && pageState.status == _PagingStatus.active) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Paging...', style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.red, size: 22),
            onPressed: () => _cancelPage(emp.uid, fs),
            tooltip: 'Cancel page',
          ),
        ],
      );
    }

    if (!canPage) {
      return Tooltip(
        message: '${emp.name} is ${emp.status.displayName.toLowerCase()}',
        child: IconButton(
          icon: Icon(Icons.notifications_off_outlined, color: Colors.grey.shade400, size: 22),
          onPressed: null,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.notifications_active, color: Color(0xFF00897B), size: 22),
      onPressed: () => _pageEmployee(emp.uid, fs),
      tooltip: 'Page employee',
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

enum _PagingStatus { active, acknowledged }

class _PageState {
  final String alertId;
  final _PagingStatus status;
  _PageState({required this.alertId, required this.status});
}
