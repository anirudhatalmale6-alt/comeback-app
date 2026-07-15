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
import 'package:comeback_app/screens/employee/my_schedule_screen.dart';
import 'package:comeback_app/screens/employee/my_appointments_screen.dart';
import 'package:comeback_app/widgets/tryon_banner.dart';

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

    _alertSub = firestore.getActivePageForEmployee(uid).listen(
      (alert) {
        if (!mounted) return;
        if (alert != null && alert.isActive && !_alarmShowing) {
          _showAlarmOverlay(alert);
        }
      },
      onError: (e) {
        debugPrint('Page alert listener error: $e');
      },
    );
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
          const MyScheduleScreen(),
          const EmployeeAppointmentsScreen(),
          _GroupChatPage(employee: employee),
          EmployeeProfileScreen(employee: employee),
        ];

        return Scaffold(
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF00897B).withValues(alpha: 0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: Color(0xFF00897B)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule, color: Color(0xFF00897B)),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF00897B)),
                label: 'Appts',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups, color: Color(0xFF00897B)),
                label: 'Chat',
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TryOnBanner(
              subtitle: 'Preview looks and share them with clients',
            ),
          ),
          Expanded(
            child: employee.isConnected
                ? _ConnectedView(employee: employee)
                : _NotConnectedView(employee: employee),
          ),
        ],
      ),
    );
  }
}

// ── Connected State ──

class _ConnectedView extends StatelessWidget {
  final EmployeeUser employee;
  const _ConnectedView({required this.employee});

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
              const SizedBox(height: 8),
              // Status selector
              GestureDetector(
                onTap: () => _showStatusPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _statusColor(employee.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(employee.status).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(employee.status), color: _statusColor(employee.status), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        employee.status.displayName,
                        style: TextStyle(
                          color: _statusColor(employee.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: _statusColor(employee.status), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF00897B), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Connected',
                              style: TextStyle(color: Color(0xFF00897B), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

// ── Group Chat Tab ──

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
