import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Check these imports match your project structure
import 'package:bookmyturf/screens/home/booking_history_screen.dart';
import 'account_settings_screen.dart';
import 'home/likes_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Fixed Background Image (Optimized: Doesn't scroll with content)
          Positioned.fill(
            child: Image.asset(
              "assets/images/turf_bg.png",
              fit: BoxFit.cover,
            ),
          ),

          // 2. Dark Overlay
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(0.55)),
          ),

          // 3. Scrollable Content
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 80, bottom: 120),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _ProfileHeader(user: user),
                  const SizedBox(height: 25),
                  const _StatsRow(),
                  const SizedBox(height: 25),
                  _buildMenuList(context),
                  const SizedBox(height: 30),
                  _LogoutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Column(
      children: [
        ProfileMenuTile(
          icon: Icons.person,
          title: "Account Settings",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
        ),
        const ProfileMenuTile(
          icon: Icons.payment,
          title: "Payment Methods",
        ),
        ProfileMenuTile(
          icon: Icons.calendar_month,
          title: "My Bookings",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen())),
        ),
        ProfileMenuTile(
          icon: Icons.favorite,
          title: "Saved Turfs",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikesScreen())),
        ),
        const ProfileMenuTile(icon: Icons.notifications, title: "Notifications"),
        const ProfileMenuTile(icon: Icons.support_agent, title: "Help & Support"),
        const ProfileMenuTile(icon: Icons.info_outline, title: "About App"),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 1. REUSABLE BOUNCY BUTTON ANIMATION WRAPPER
// ----------------------------------------------------------------------
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.95,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onPressed != null) {
      // Small delay to let the animation play
      Future.delayed(const Duration(milliseconds: 100), () {
        widget.onPressed!();
      });
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. WIDGETS (Extracted for Performance)
// ----------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  final User? user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 330,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.greenAccent.withOpacity(0.3),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : const AssetImage("assets/images/default_user.png") as ImageProvider,
                ),
                const SizedBox(height: 14),
                Text(
                  user?.displayName ?? "Guest User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? user?.phoneNumber ?? "No email/phone linked",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Using BouncyButton for the Edit Action
                BouncyButton(
                  onPressed: () {
                    // Navigate to Edit Profile
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      "Edit Profile",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatCard(title: "Bookings", value: "24", icon: Icons.calendar_month),
          StatCard(title: "Wallet", value: "₹850", icon: Icons.account_balance_wallet),
          StatCard(title: "Saved", value: "12", icon: Icons.favorite),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Making stats bouncy too because it feels nice
    return BouncyButton(
      scaleFactor: 0.90,
      onPressed: () {
        // Optional: Navigate to detailed stat view
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 95,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.greenAccent, size: 26),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      child: BouncyButton(
        onPressed: onTap ?? () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withOpacity(0.10),
              child: Row(
                children: [
                  Icon(icon, color: Colors.greenAccent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: BouncyButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            color: Colors.redAccent.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              "Log Out",
              style: TextStyle(
                color: Colors.redAccent.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}