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
import 'package:comeback_app/screens/customer/customer_messages_screen.dart';
import 'package:comeback_app/screens/customer/virtual_tryon_screen.dart';

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
          CustomerHomeTab(
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
          bottomNavigationBar: Container(
            // One hairline along the top of the bar. Material's default tinted
            // slab competed with the page for attention.
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0x14000000))),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 66,
              indicatorColor: const Color(0xFF00897B).withValues(alpha: 0.10),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final bool sel = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.1,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? const Color(0xFF00897B) : Colors.grey.shade600,
                );
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF00897B)),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon:
                      Icon(Icons.search_rounded, color: Color(0xFF00897B)),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_available_outlined),
                  selectedIcon:
                      Icon(Icons.event_available_rounded, color: Color(0xFF00897B)),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon:
                      Icon(Icons.photo_library_rounded, color: Color(0xFF00897B)),
                  label: 'My Nails',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon:
                      Icon(Icons.person_rounded, color: Color(0xFF00897B)),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CustomerHomeTab extends StatelessWidget {
  final CustomerUser customer;
  final ValueChanged<int> onNavigate;
  const CustomerHomeTab(
      {super.key, required this.customer, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // The first name only. "Hi, Ashlyn Marie Nguyen!" wraps to two lines on a
    // narrow phone and takes the calm out of the top of the screen.
    final String first = customer.name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      // A very soft warm wash instead of the flat grey. It's subtle on purpose —
      // you shouldn't be able to point at it, it should just stop the screen
      // feeling like a settings page.
      backgroundColor: const Color(0xFFFCFAFA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Come Back',
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.4),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerMessagesScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAF9), Color(0xFFFCFAFA)],
            stops: [0.0, 0.4],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // A thin blush ring around the avatar — one hairline does more
                  // for "considered" than any amount of extra shadow.
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFEC407A).withValues(alpha: 0.28),
                          width: 1.2),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE6F3F1),
                      backgroundImage: customer.photoUrl != null
                          ? CachedNetworkImageProvider(customer.photoUrl!)
                          : null,
                      child: customer.photoUrl == null
                          ? const Icon(Icons.person_outline,
                              size: 26, color: Color(0xFF00897B))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Hi," light, the name weighted. Setting the greeting
                        // and the name at the same weight is what made this read
                        // as a form label rather than a welcome.
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Hi, ',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w300,
                                  color: Color(0xFF3A3A3A),
                                ),
                              ),
                              TextSpan(
                                text: first,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2A2A),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Find your favourite nail salon',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _TryOnBanner(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VirtualTryOnScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const _SectionLabel('QUICK ACTIONS'),
              const SizedBox(height: 12),
              _QuickActionCard(
                icon: Icons.search_rounded,
                title: 'Find a Salon',
                subtitle: 'Search salons near you',
                color: const Color(0xFF00897B),
                onTap: () => onNavigate(1),
              ),
              const SizedBox(height: 10),
              _QuickActionCard(
                icon: Icons.favorite_outline_rounded,
                title: 'Favourites',
                subtitle: customer.favoriteSalonIds.isEmpty
                    ? 'No favourites yet'
                    : '${customer.favoriteSalonIds.length} saved salons',
                color: const Color(0xFFE91E63),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FavoriteSalonsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _QuickActionCard(
                icon: Icons.event_available_outlined,
                title: 'My Appointments',
                subtitle: 'View upcoming bookings',
                color: const Color(0xFF3F7FD4),
                onTap: () => onNavigate(2),
              ),
              const SizedBox(height: 10),
              _QuickActionCard(
                icon: Icons.photo_camera_outlined,
                title: 'My Nail Photos',
                subtitle: 'Save designs for next visit',
                color: const Color(0xFF8E5BC7),
                onTap: () => onNavigate(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet uppercase label above a group. Cheap, and it's what turns a stack of
/// four cards into a section rather than a pile.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _TryOnBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _TryOnBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // A coloured glow rather than a grey drop shadow. Grey under a pink
        // gradient always looks like dirt; the card's own colour, spread wide
        // and faint, is what makes it sit on the page instead of on top of it.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC407A).withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF0578A), Color(0xFF9B5DE5), Color(0xFF7048C4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Two very faint discs bleeding off the right edge. They read as
                // light on a curved surface and stop the gradient looking like a
                // flat swatch.
                Positioned(
                  right: -34,
                  top: -46,
                  child: _Glow(size: 130, alpha: 0.13),
                ),
                Positioned(
                  right: 44,
                  bottom: -60,
                  child: _Glow(size: 108, alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.32),
                              width: 1),
                        ),
                        child: const Icon(Icons.auto_awesome_outlined,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Virtual Nail Try-On',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17.5,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                _NewBadge(),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Try any design on your own hand',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft white disc used as a decorative light bloom inside the banner.
class _Glow extends StatelessWidget {
  final double size;
  final double alpha;
  const _Glow({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Color(0xFFE0407A),
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
          letterSpacing: 0.7,
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
    // A hairline border plus a wide, very faint shadow, instead of Material's
    // elevation. Elevation 1 on four stacked cards is what made this screen look
    // like a stack of grey boxes; a 1px line at 7% black reads as a card without
    // shouting about it.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2A2A).withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2A2A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.16),
                        color.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            letterSpacing: 0.1,
                            color: Color(0xFF1F2A2A),
                          )),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade400, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
