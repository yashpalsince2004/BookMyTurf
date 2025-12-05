import 'dart:ui';
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
    // 1. EXTRACT DATA SAFELY
    final turfId = bookingData["turf_id"] ?? "";
    final int price = (bookingData["amount_total"] ?? 0).toInt();
    final int amountPaid = (bookingData["amount_paid"] ?? 0).toInt();
    final int amountBalance = price - amountPaid;

    // --- ⚡️ UPDATED: TIME SLOT RANGE LOGIC ⚡️ ---
    // Instead of joining all slots, we extract Start of First & End of Last
    String slotDisplay = "N/A";

    // Check if we have the pre-calculated display string first
    if (bookingData["slot_display"] != null) {
      slotDisplay = bookingData["slot_display"];
    }
    else {
      // Fallback: Calculate from the list if 'slot_display' is missing
      List<dynamic> rawSlots = [];
      if (bookingData["slots"] is List) {
        rawSlots = bookingData["slots"];
      } else if (bookingData["slot"] is List) {
        rawSlots = bookingData["slot"];
      } else if (bookingData["slot"] is String) {
        rawSlots = [bookingData["slot"]];
      }

      if (rawSlots.isNotEmpty) {
        // Example List: ["6:00 AM - 7:00 AM", "7:00 AM - 8:00 AM"]
        String firstSlot = rawSlots.first.toString(); // "6:00 AM - 7:00 AM"
        String lastSlot = rawSlots.last.toString();   // "7:00 AM - 8:00 AM"

        // Extract "6:00 AM" from first
        String startTime = firstSlot.split('-')[0].trim();
        // Extract "8:00 AM" from last
        String endTime = lastSlot.split('-')[1].trim();

        slotDisplay = "$startTime - $endTime";
      }
    }
    // ---------------------------------------------

    final dateStr = bookingData["slot_date"];
    final status = bookingData["status"] ?? "confirmed";
    final paymentMethod = bookingData["payment_method"] ?? "N/A";
    final initialTurfName = bookingData["turf_name"] ?? "Loading Name...";

    // 2. DATE PARSING
    String formattedDate = dateStr ?? "Unknown Date";
    if (dateStr != null) {
      try {
        final parsedDate = DateFormat("dd/MM/yyyy").parse(dateStr);
        formattedDate = DateFormat("dd MMM yyyy").format(parsedDate);
      } catch (e) {
        formattedDate = dateStr;
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Booking Details", style: TextStyle(color: Colors.white)),
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
                color: Colors.black.withOpacity(0.85),
              ),
            ),
          ),

          // FETCH TURF IMAGE
          FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('turfs').doc(turfId).get(),
              builder: (context, snapshot) {
                String displayTurfName = initialTurfName;
                String displayTurfImage = "https://i.ibb.co/vJkFq7k/no-image.jpg";

                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                  final turfData = snapshot.data!.data() as Map<String, dynamic>;
                  if (turfData['turf_name'] != null) displayTurfName = turfData['turf_name'];
                  if (turfData['images'] != null && (turfData['images'] as List).isNotEmpty) {
                    displayTurfImage = turfData['images'][0];
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 110, 20, 30),
                  child: Column(
                    children: [
                      // --- IMAGE CARD ---
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            displayTurfImage,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(height: 220, color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- DETAILS GLASS PANE ---
                      _GlassPane(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayTurfName,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                                  ),
                                ),
                                _buildStatusChip(status),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 24),

                            // Row 1: Date & Time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _InfoItem(icon: Icons.calendar_today, label: "Date", value: formattedDate)),
                                // ⚡️ THIS NOW SHOWS ONLY START - END ⚡️
                                Expanded(child: _InfoItem(icon: Icons.access_time, label: "Time Slots", value: slotDisplay)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Row 2: Payment Method & Grand Total
                            Row(
                              children: [
                                Expanded(child: _InfoItem(icon: Icons.payment, label: "Payment Via", value: paymentMethod)),
                                Expanded(
                                    child: _InfoItem(
                                        icon: Icons.monetization_on,
                                        label: "Grand Total",
                                        value: "₹$price",
                                        customColor: Colors.white,
                                        isLarge: true
                                    )
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 20),

                            // --- PAYMENT BREAKDOWN ---
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  // Total Paid
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF00E676)),
                                            const SizedBox(width: 6),
                                            Text("Total Paid", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹$amountPaid",
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Vertical Divider
                                  Container(width: 1, height: 40, color: Colors.white24),
                                  const SizedBox(width: 16),

                                  // Balance Due
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                                amountBalance > 0 ? Icons.info_outline : Icons.check,
                                                size: 16,
                                                color: amountBalance > 0 ? Colors.redAccent : Colors.grey
                                            ),
                                            const SizedBox(width: 6),
                                            Text("Balance Due", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹$amountBalance",
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: amountBalance > 0 ? Colors.redAccent : Colors.white54
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- BUTTONS ---
                      if (amountBalance > 0 && status != "cancelled") ...[
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => _completePayment(context, amountBalance),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payment, color: Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  "Pay Balance ₹$amountBalance",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (status != "cancelled")
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => _cancelBooking(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.9),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Cancel Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),

                      if (status == "cancelled")
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Text("This booking has been cancelled.", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                );
              }
          ),
        ],
      ),
    );
  }

  // ... (Your existing _completePayment, _cancelBooking, _InfoItem, and _GlassPane classes remain the same)

  // --------------------- COMPLETE PAYMENT (Include this for context) ---------------------
  Future<void> _completePayment(BuildContext context, int amount) async {
    final bookingTimestamp = bookingData['timestamp'];
    if (bookingTimestamp == null) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("Complete Payment", style: TextStyle(color: Colors.white)),
        content: Text("Proceed to pay the remaining balance of ₹$amount?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing Payment...")));

              try {
                final querySnapshot = await FirebaseFirestore.instance
                    .collection('bookings')
                    .where('timestamp', isEqualTo: bookingTimestamp)
                    .get();

                WriteBatch batch = FirebaseFirestore.instance.batch();
                final docs = querySnapshot.docs;

                if (docs.isNotEmpty) {
                  final mainDoc = docs.first;
                  final totalAmount = mainDoc['amount_total'] ?? 0;

                  batch.update(mainDoc.reference, {
                    'amount_balance': 0,
                    'amount_paid': totalAmount,
                    'status': 'confirmed'
                  });

                  for (int i = 1; i < docs.length; i++) {
                    batch.update(docs[i].reference, {
                      'amount_balance': 0,
                      'amount_paid': 0,
                      'amount_total': 0,
                      'status': 'merged_legacy'
                    });
                  }
                }

                await batch.commit();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green));
                  Navigator.pop(context);
                }
              } catch (e) {
                print(e);
              }
            },
            child: const Text("Pay Now", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Booking?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to cancel this booking?\nThis action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No, Keep it", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection("bookings").doc(bookingId).update({"status": "cancelled"});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Cancelled!"), backgroundColor: Colors.redAccent));
      Navigator.pop(context);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color = status.toLowerCase() == "cancelled" ? Colors.redAccent : (status.toLowerCase() == "pending" ? Colors.orangeAccent : Colors.greenAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? customColor;
  final bool isLarge;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.customColor,
    this.isLarge = false,
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
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: customColor ?? Colors.white,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

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
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.0),
      ),
      child: child,
    );
  }
}
