import 'dart:ui'; // Required for ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const BookingDetailsScreen({
    super.key,
    required this.bookingData,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    final turfName = bookingData["turfName"] ?? "Unknown Turf";
    final turfImage =
        bookingData["turfImage"] ?? "https://i.ibb.co/vJkFq7k/no-image.jpg";
    final price = bookingData["price"] ?? 0;
    final slot = bookingData["slot"] ?? "N/A";
    final date = bookingData["date"];
    final status = bookingData["status"] ?? "confirmed";

    String formattedDate = "Unknown Date";
    if (date != null) {
      try {
        formattedDate = DateFormat("dd MMM yyyy").format(DateTime.parse(date));
      } catch (_) {}
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Booking Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. FIXED BACKGROUND IMAGE (Covers entire screen)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/turf_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.85), // Dark overlay
              ),
            ),
          ),

          // 2. SCROLLABLE CONTENT (Using SliverFillRemaining for perfect layout)
          CustomScrollView(
            slivers: [
              // Spacer for AppBar height + extra padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ),

              SliverFillRemaining(
                hasScrollBody: false, // Ensures content stretches to fill screen
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      // --- TOP CONTENT ---

                      // IMAGE CARD
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            turfImage,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 220,
                              color: Colors.white10,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.white24, size: 50),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // DETAILS GLASS PANE
                      _GlassPane(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    turfName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                _buildStatusChip(status),
                              ],
                            ),

                            const SizedBox(height: 24),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 24),

                            // Grid of Details
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoItem(
                                    icon: Icons.calendar_today,
                                    label: "Date",
                                    value: formattedDate,
                                  ),
                                ),
                                Expanded(
                                  child: _InfoItem(
                                    icon: Icons.access_time,
                                    label: "Time Slot",
                                    value: slot,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Price Row
                            _InfoItem(
                              icon: Icons.currency_rupee,
                              label: "Total Price",
                              value: "₹$price",
                              isPrice: true,
                            ),
                          ],
                        ),
                      ),

                      // --- SPACER ---
                      // This pushes everything below it to the bottom of the screen
                      const Spacer(),

                      const SizedBox(height: 30),

                      // --- BOTTOM ACTION BUTTON ---
                      SafeArea(
                        top: false, // Only respect bottom safe area
                        child: Column(
                          children: [
                            if (status != "cancelled")
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: () => _cancelBooking(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    Colors.redAccent.withOpacity(0.9),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cancel Booking",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),

                            // If cancelled text
                            if (status == "cancelled")
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  "This booking has been cancelled.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------- CANCEL BOOKING ---------------------

  void _cancelBooking(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF222222), // Dark dialog
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Booking?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to cancel this booking?\nThis action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("No, Keep it",
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes, Cancel",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection("bookings")
        .doc(bookingId)
        .update({"status": "cancelled"});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Booking Cancelled!"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  // --------------------- WIDGETS ---------------------

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style:
        TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// Helper Widget for Grid Info Items
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPrice;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isPrice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isPrice ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isPrice ? Colors.greenAccent : Colors.white,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// REUSABLE GLASS PANE
// ---------------------------------------------------------------------
class _GlassPane extends StatelessWidget {
  final Widget child;

  const _GlassPane({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}