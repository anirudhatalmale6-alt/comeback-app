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
import 'package:comeback_app/screens/customer/customer_dashboard.dart';
import 'package:comeback_app/utils/app_theme.dart';
import 'package:comeback_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  String _status = 'Starting...';
  bool _ready = false;
  String? _error;
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() => _status = 'Initializing Firebase...');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Firebase init timed out after 10s'),
      );

      try {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      } catch (_) {}

      setState(() => _status = 'Firebase OK. Setting up notifications...');

      _notificationService = NotificationService();
      try {
        await _notificationService!.initialize().timeout(
              const Duration(seconds: 5),
              onTimeout: () =>
                  throw Exception('Notification init timed out'),
            );
      } catch (_) {}

      setState(() {
        _status = 'Ready!';
        _ready = true;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _status = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 60),
                  const SizedBox(height: 16),
                  const Text('Startup Error',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF00897B),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.spa, color: Colors.white, size: 60),
                const SizedBox(height: 20),
                const Text('Come Back',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(_status,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<NotificationService>.value(
            value: _notificationService ?? NotificationService()),
      ],
      child: MaterialApp(
        title: 'Come Back',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/owner-dashboard': (_) => const OwnerDashboard(),
          '/employee-dashboard': (_) => const EmployeeDashboard(),
          '/customer-dashboard': (_) => const CustomerDashboard(),
        },
      ),
    );
  }
}
