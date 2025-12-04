import 'dart:ui'; // Required for ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_details_screen.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // --- 1. HANDLE NOT LOGGED IN ---
    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildGlassAppBar("My Bookings"),
        body: const Center(
          child: Text("Please login to view bookings.",
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    // --- 2. MAIN UI ---
    return Scaffold(
      extendBodyBehindAppBar: true, // Important for glass effect
      backgroundColor: Colors.black,
      appBar: _buildGlassAppBar("My Bookings"),
      body: Stack(
        children: [
          // BACKGROUND IMAGE
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/loc_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.8), // Darker overlay for text readability
              ),
            ),
          ),

          // LIST CONTENT
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("bookings")
                .where("userId", isEqualTo: userId)
                .orderBy("timestamp", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.white24),
                      SizedBox(height: 16),
                      Text("No bookings yet.",
                          style: TextStyle(fontSize: 16, color: Colors.white54)),
                    ],
                  ),
                );
              }

              final bookings = snapshot.data!.docs;

              return ListView.builder(
                // Add padding for AppBar height so items aren't hidden behind it
                padding: const EdgeInsets.only(top: 110, left: 16, right: 16, bottom: 20),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final data = bookings[index].data();
                  final bookingId = bookings[index].id;

                  return _BookingCard(data: data, bookingId: bookingId);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper method for consistent Glass AppBar
  PreferredSizeWidget _buildGlassAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------
// UPDATED CARD COMPONENT
// ---------------------------------------------
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const _BookingCard({required this.data, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    // 1. Get the turfId from the booking data to fetch the specific turf info
    final turfId = data["turfId"];
    final slot = data["slot"] ?? "N/A";
    final date = data["date"];
    final status = data["status"] ?? "confirmed";

    // Format Date
    String formattedDate = "Unknown Date";
    if (date != null) {
      try {
        formattedDate = DateFormat("dd MMM yyyy").format(DateTime.parse(date));
      } catch (e) {
        formattedDate = date.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassPane(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailsScreen(
                bookingData: data,
                bookingId: bookingId,
              ),
            ),
          );
        },
        // 2. Use FutureBuilder to fetch 'turf_name' and 'images' from the 'turfs' collection
        child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('turfs').doc(turfId).get(),
            builder: (context, snapshot) {

              // Default/Loading values
              String displayTurfName = "Loading...";
              String displayTurfImage = "https://i.ibb.co/vJkFq7k/no-image.jpg"; // Placeholder

              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                final turfData = snapshot.data!.data() as Map<String, dynamic>;

                // --- KEY CHANGES BASED ON YOUR SCREENSHOT ---
                displayTurfName = turfData['turf_name'] ?? "Unknown Turf";

                if (turfData['images'] != null && (turfData['images'] as List).isNotEmpty) {
                  displayTurfImage = turfData['images'][0]; // Get the first image
                }
              } else if (snapshot.hasError) {
                displayTurfName = "Error loading turf";
              }

              return Row(
                children: [
                  // ----- LEFT: TEXT INFO -----
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTurfName, // Using the fetched name
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Row for Date & Time icons
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(formattedDate,
                                style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(slot,
                                style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatusChip(status),
                            const Spacer(),
                            const Text(
                              "More details >",
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ----- RIGHT: IMAGE -----
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      displayTurfImage, // Using the fetched image
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.white10,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.white10,
                        child: const Icon(Icons.broken_image, color: Colors.white24),
                      ),
                    ),
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case "cancelled":
        color = Colors.redAccent;
        label = "Cancelled";
        break;
      case "pending":
        color = Colors.orangeAccent;
        label = "Pending";
        break;
      default:
        color = Colors.greenAccent;
        label = "Confirmed";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
// ---------------------------------------------------------------------
// REUSABLE GLASS PANE (COPIED FROM HOME SCREEN)
// ---------------------------------------------------------------------
class _GlassPane extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GlassPane({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // Frosted glass look
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child, // No Blur here for performance (same as Home Screen optimization)
          ),
        ),
      ),
    );
  }
}