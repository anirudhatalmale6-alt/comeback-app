import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/services/notification_service.dart';
import 'package:comeback_app/services/storage_service.dart';
import 'package:comeback_app/screens/auth/auth_wrapper.dart';
import 'package:comeback_app/screens/owner/owner_dashboard.dart';
import 'package:comeback_app/screens/employee/employee_dashboard.dart';
import 'package:comeback_app/utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final notificationService = NotificationService();
  await notificationService.initialize();
  runApp(ComeBackApp(notificationService: notificationService));
}

class ComeBackApp extends StatelessWidget {
  final NotificationService notificationService;

  const ComeBackApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<NotificationService>.value(value: notificationService),
      ],
      child: MaterialApp(
        title: 'Come Back',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/owner-dashboard': (_) => const OwnerDashboard(),
          '/employee-dashboard': (_) => const EmployeeDashboard(),
        },
      ),
    );
  }
}
