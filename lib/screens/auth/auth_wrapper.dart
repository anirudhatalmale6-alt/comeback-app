import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/notification_service.dart';
import 'package:comeback_app/screens/auth/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE0F2F1),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00897B),
              ),
            ),
          );
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in - determine role and route
        return _RoleRouter(uid: snapshot.data!.uid);
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  final String uid;
  const _RoleRouter({required this.uid});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  void _saveFcmToken(String uid) {
    final notif = context.read<NotificationService>();
    final firestore = context.read<FirestoreService>();

    NotificationService.setCurrentUid(uid);
    NotificationService.onTokenRefresh = (refreshUid, token) {
      firestore.updateFcmToken(refreshUid, token);
      firestore.updateUser(refreshUid, {'fcmDebug': 'token_from_refresh'});
    };

    _attemptTokenSave(notif, firestore, uid);
  }

  Future<void> _attemptTokenSave(
      NotificationService notif, FirestoreService firestore, String uid) async {
    try {
      final permStatus = await notif.getPermissionStatus();
      await firestore.updateUser(uid, {
        'fcmDebug': 'perm=$permStatus, waiting_for_token...',
      });

      for (int attempt = 1; attempt <= 10; attempt++) {
        final token = await notif.getToken();
        if (token != null) {
          await firestore.updateFcmToken(uid, token);
          await firestore.updateUser(uid, {
            'fcmDebug': 'token_saved_attempt_$attempt',
          });
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
      }

      final apns = await notif.getAPNSToken();
      await firestore.updateUser(uid, {
        'fcmDebug': 'all_attempts_failed, apns=${apns != null ? "yes" : "null"}',
      });
    } catch (e) {
      try {
        await firestore.updateUser(uid, {'fcmDebug': 'error: $e'});
      } catch (_) {}
    }
  }

  Future<void> _routeUser() async {
    try {
      final firestore = context.read<FirestoreService>();
      final user = await firestore.getUser(widget.uid);

      if (!mounted) return;

      if (user is OwnerUser || user is EmployeeUser) {
        _saveFcmToken(widget.uid);
        final route = user is OwnerUser ? '/owner-dashboard' : '/employee-dashboard';
        Navigator.of(context).pushReplacementNamed(route);
      } else {
        // User doc not found - sign out and show login
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      if (!mounted) return;
      // On error, sign out so user can retry
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE0F2F1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00897B)),
            SizedBox(height: 16),
            Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: Color(0xFF00897B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
