import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/screens/customer/search_salons_screen.dart';
import 'package:comeback_app/screens/customer/customer_profile_screen.dart';
import 'package:comeback_app/screens/customer/my_appointments_screen.dart';
import 'package:comeback_app/screens/customer/nail_photos_screen.dart';
import 'package:comeback_app/screens/customer/favorite_salons_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<AppUser?>(
      stream: firestore.userStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Something went wrong:\n${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (_) => false);
                        }
                      },
                      child: const Text('Sign Out & Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null || user is! CustomerUser) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = [
          _HomeTab(
            customer: user,
            onNavigate: (i) => setState(() => _currentIndex = i),
          ),
          const SearchSalonsScreen(),
          const MyAppointmentsScreen(),
          const NailPhotosScreen(),
          CustomerProfileScreen(customer: user),
        ];

        return Scaffold(
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: 'My Nails',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  final CustomerUser customer;
  final ValueChanged<int> onNavigate;
  const _HomeTab({required this.customer, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Come Back'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE0F2F1),
                  backgroundImage: customer.photoUrl != null
                      ? CachedNetworkImageProvider(customer.photoUrl!)
                      : null,
                  child: customer.photoUrl == null
                      ? const Icon(Icons.person,
                          size: 28, color: Color(0xFF00897B))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${customer.name}!',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Find your favorite nail salon',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _QuickActionCard(
              icon: Icons.search,
              title: 'Find a Salon',
              subtitle: 'Search salons near you',
              color: const Color(0xFF00897B),
              onTap: () => onNavigate(1),
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.favorite_outline,
              title: 'Favorites',
              subtitle: customer.favoriteSalonIds.isEmpty
                  ? 'No favorites yet'
                  : '${customer.favoriteSalonIds.length} saved salons',
              color: Colors.pink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FavoriteSalonsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.calendar_today,
              title: 'My Appointments',
              subtitle: 'View upcoming bookings',
              color: Colors.blue,
              onTap: () => onNavigate(2),
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.photo_camera,
              title: 'My Nail Photos',
              subtitle: 'Save designs for next visit',
              color: Colors.purple,
              onTap: () => onNavigate(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
