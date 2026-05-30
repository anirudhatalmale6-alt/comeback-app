import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/models/page_alert.dart';
import 'package:comeback_app/models/connection_request.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/screens/employee/alarm_overlay.dart';
import 'package:comeback_app/screens/employee/employee_profile_screen.dart';
import 'package:comeback_app/screens/chat/chat_screen.dart';
import 'package:comeback_app/screens/chat/group_chat_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentIndex = 0;
  StreamSubscription<PageAlert?>? _alertSub;
  bool _alarmShowing = false;

  @override
  void initState() {
    super.initState();
    _listenForAlerts();
  }

  void _listenForAlerts() {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final uid = auth.getCurrentUser()?.uid;
    if (uid == null) return;

    _alertSub = firestore.getActivePageForEmployee(uid).listen((alert) {
      if (!mounted) return;
      if (alert != null && alert.isActive && !_alarmShowing) {
        _showAlarmOverlay(alert);
      }
    });
  }

  Future<void> _showAlarmOverlay(PageAlert alert) async {
    _alarmShowing = true;
    final firestore = context.read<FirestoreService>();
    final owner = await firestore.getUser(alert.ownerId);
    final ownerName = owner is OwnerUser ? owner.businessName : 'Your Boss';

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlarmOverlay(alert: alert, ownerName: ownerName),
      ),
    );
    _alarmShowing = false;
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final uid = auth.getCurrentUser()!.uid;

    return StreamBuilder<AppUser?>(
      stream: firestore.userStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final employee = snapshot.data! as EmployeeUser;
        final pages = <Widget>[
          _HomePage(employee: employee),
          _GroupChatPage(employee: employee),
          EmployeeProfileScreen(employee: employee),
        ];

        return Scaffold(
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF00897B).withOpacity(0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: Color(0xFF00897B)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups, color: Color(0xFF00897B)),
                label: 'Group Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outlined),
                selectedIcon: Icon(Icons.person, color: Color(0xFF00897B)),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Home Tab ──

class _HomePage extends StatelessWidget {
  final EmployeeUser employee;
  const _HomePage({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        title: const Text('Come Back'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: employee.isConnected
          ? _ConnectedView(employee: employee)
          : _NotConnectedView(employee: employee),
    );
  }
}

// ── Connected State ──

class _ConnectedView extends StatelessWidget {
  final EmployeeUser employee;
  const _ConnectedView({required this.employee});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<AppUser?>(
      stream: firestore.userStream(employee.connectedOwnerId!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final owner = snap.data! as OwnerUser;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Connection status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00897B), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Owner info card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF00897B),
                        backgroundImage: owner.photoUrl != null
                            ? NetworkImage(owner.photoUrl!)
                            : null,
                        child: owner.photoUrl == null
                            ? Text(
                                owner.businessName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        owner.businessName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        owner.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: owner.uid,
                            otherUserName: owner.name,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(
                            ownerId: owner.uid,
                            businessName: owner.businessName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Group'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B).withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Not Connected State ──

class _NotConnectedView extends StatelessWidget {
  final EmployeeUser employee;
  const _NotConnectedView({required this.employee});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text(
                  'Not Connected',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Connection code card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Your Connection Code',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    employee.connectionCode,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: employee.connectionCode,
                    version: QrVersions.auto,
                    size: 180,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF00897B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share this code with your salon owner',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Pending requests
          StreamBuilder<List<ConnectionRequest>>(
            stream: firestore.getConnectionRequests(employee.uid),
            builder: (context, snap) {
              final requests = snap.data ?? [];
              if (requests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...requests.map((req) => _RequestCard(request: req)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ConnectionRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00897B),
              child: Text(
                request.businessName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.businessName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    request.ownerName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => firestore.declineConnection(request.id),
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Decline',
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => firestore.acceptConnection(
                request.id,
                request.fromOwnerId,
                request.toEmployeeId,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group Chat Tab (redirects to group chat if connected) ──

class _GroupChatPage extends StatelessWidget {
  final EmployeeUser employee;
  const _GroupChatPage({required this.employee});

  @override
  Widget build(BuildContext context) {
    if (!employee.isConnected) {
      return Scaffold(
        backgroundColor: const Color(0xFFE0F2F1),
        appBar: AppBar(
          title: const Text('Group Chat'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Connect to a salon first',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GroupChatScreen(
      ownerId: employee.connectedOwnerId!,
    );
  }
}
