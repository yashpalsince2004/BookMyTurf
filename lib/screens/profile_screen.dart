import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Turf Image
          Positioned.fill(
            child: Image.asset(
              "assets/images/turf_bg.png",
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),

          // Main Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 80, bottom: 140),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildProfileHeader(user),
                const SizedBox(height: 20),
                _buildStatsRow(),
                const SizedBox(height: 20),
                _buildMenuList(context),
                const SizedBox(height: 20),
                _logoutButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // PROFILE HEADER WITH FIREBASE USER
  // ----------------------------------------------------------------------
  Widget _buildProfileHeader(User? user) {
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
                // Profile Avatar
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.greenAccent.withOpacity(0.3),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : const AssetImage("assets/images/default_user.png")
                  as ImageProvider,
                ),

                const SizedBox(height: 14),

                // Name
                Text(
                  user?.displayName ?? "Guest User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                // Email or phone
                Text(
                  user?.email ??
                      user?.phoneNumber ??
                      "No email/phone linked",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 16),

                // Edit Button
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Edit Profile",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // STATIC STATS (can link with backend later)
  // ----------------------------------------------------------------------
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCard("Bookings", "24", Icons.calendar_month),
          _statCard("Wallet", "₹850", Icons.account_balance_wallet),
          _statCard("Saved", "12", Icons.favorite),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return ClipRRect(
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
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // MENU LIST
  // ----------------------------------------------------------------------
  Widget _buildMenuList(BuildContext context) {
    return Column(
      children: [
        _menuTile(Icons.person, "Account Settings", onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          );
        }),

        _menuTile(Icons.payment, "Payment Methods"),
        _menuTile(Icons.calendar_month, "My Bookings"),
        _menuTile(Icons.favorite, "Saved Turfs"),
        _menuTile(Icons.notifications, "Notifications"),
        _menuTile(Icons.support_agent, "Help & Support"),
        _menuTile(Icons.info_outline, "About App"),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ListTile(
            tileColor: Colors.white.withOpacity(0.10),
            leading: Icon(icon, color: Colors.greenAccent),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 16),
            onTap: onTap,
          ),
        ),
      ),
    );
  }


  // ----------------------------------------------------------------------
  // LOGOUT BUTTON
  // ----------------------------------------------------------------------
  Widget _logoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: TextButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
        },
        child: Text(
          "Log Out",
          style: TextStyle(
            color: Colors.redAccent.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
