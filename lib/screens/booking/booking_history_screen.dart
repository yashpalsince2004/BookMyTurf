//lib/home/booking_history_screen.dart
import 'dart:ui';
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

    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildGlassAppBar("My Bookings"),
        body: const Center(child: Text("Please login first.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _buildGlassAppBar("My Bookings"),
      body: Stack(
        children: [
          // BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/loc_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(color: Colors.black.withOpacity(0.8)),
            ),
          ),

          // LIST CONTENT
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("bookings")
                .where("user_id", isEqualTo: userId)
                .orderBy("timestamp", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
              }

              if (snapshot.hasError) {
                debugPrint("Error: ${snapshot.error}");
                return const Center(child: Text("Error loading bookings.", style: TextStyle(color: Colors.red)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.white24),
                      SizedBox(height: 16),
                      Text("No bookings yet.", style: TextStyle(fontSize: 16, color: Colors.white54)),
                    ],
                  ),
                );
              }

              // --- KEY CHANGE: GROUP THE BOOKINGS BEFORE DISPLAYING ---
              final groupedBookings = _groupBookings(snapshot.data!.docs);

              return ListView.builder(
                padding: const EdgeInsets.only(top: 110, left: 16, right: 16, bottom: 20),
                itemCount: groupedBookings.length,
                itemBuilder: (context, index) {
                  final bookingData = groupedBookings[index];
                  // We use the ID of the *first* booking in the group for navigation logic
                  final primaryBookingId = bookingData['primary_id'];

                  return _BookingCard(data: bookingData, bookingId: primaryBookingId);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- LOGIC TO MERGE CONSECUTIVE SLOTS ---
  // --- UPDATED LOGIC: MERGE ONLY SAME TIMESTAMP ---
  List<Map<String, dynamic>> _groupBookings(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];

    List<Map<String, dynamic>> rawList = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['primary_id'] = doc.id;
      return data;
    }).toList();

    // SORTING IS CRITICAL
    rawList.sort((a, b) {
      // 1. Compare Timestamps (Descending) - Keep batch bookings together
      Timestamp tA = a['timestamp'];
      Timestamp tB = b['timestamp'];
      int timeComp = tB.compareTo(tA);
      if (timeComp != 0) return timeComp;

      // 2. Compare Slot Start Time (Ascending) - Ensure 6am comes before 7am
      DateTime? slotA = _parseSlotStart(a['slot']);
      DateTime? slotB = _parseSlotStart(b['slot']);
      return (slotA ?? DateTime(0)).compareTo(slotB ?? DateTime(0));
    });

    List<Map<String, dynamic>> grouped = [];

    for (var currentData in rawList) {
      if (grouped.isEmpty) {
        grouped.add(currentData);
        continue;
      }

      var lastGroup = grouped.last;

      // --- THE NEW STRICT RULE ---
      // Only merge if they have the EXACT same timestamp (booked together)
      bool sameTimestamp = lastGroup['timestamp'] == currentData['timestamp'];
      bool sameTurf = lastGroup['turf_id'] == currentData['turf_id'];

      if (sameTimestamp && sameTurf) {
        try {
          // Check Continuity: Ends at 7:00 AM == Starts at 7:00 AM?
          String lastEndTime = lastGroup['slot'].split(" - ")[1].trim();
          String currentStartTime = currentData['slot'].split(" - ")[0].trim();

          if (lastEndTime == currentStartTime) {
            // MERGE: Update the previous card to extend the time
            String newStart = lastGroup['slot'].split(" - ")[0];
            String newEnd = currentData['slot'].split(" - ")[1];

            lastGroup['slot'] = "$newStart - $newEnd";

            // Sum the cost (optional but recommended)
            if (lastGroup['amount_paid'] != null && currentData['amount_paid'] != null) {
              num p1 = lastGroup['amount_paid'];
              num p2 = currentData['amount_paid'];
              lastGroup['amount_paid'] = p1 + p2;
            }
            continue; // Skip adding the current card since we merged it
          }
        } catch (e) {
          debugPrint("Merge error: $e");
        }
      }

      grouped.add(currentData);
    }

    return grouped;
  }

  // Helper: Parses "6:00 AM" from "6:00 AM - 7:00 AM"
  DateTime? _parseSlotStart(String? slotStr) {
    if (slotStr == null) return null;
    try {
      String startTime = slotStr.split(" - ")[0].trim();
      return DateFormat("h:mm a").parse(startTime);
    } catch (e) {
      return null;
    }
  }
  PreferredSizeWidget _buildGlassAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.4)),
        ),
      ),
    );
  }
}

// ---------------------------------------------
// CARD COMPONENT (No Changes needed here, it just receives the merged string)
// ---------------------------------------------
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const _BookingCard({required this.data, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final turfId = data["turf_id"];
    final slot = data["slot"] ?? "N/A"; // This will now show merged time "6:00 AM - 8:00 AM"
    final slotDate = data["slot_date"];
    final status = data["status"] ?? "confirmed";
    final initialTurfName = data["turf_name"] ?? "Loading...";

    // Optional: Show total cost if merged
    final amountPaid = data['amount_paid'];

    String formattedDate = "Unknown Date";
    if (slotDate != null) {
      try {
        DateTime parsed = DateFormat("dd/MM/yyyy").parse(slotDate);
        formattedDate = DateFormat("dd MMM yyyy").format(parsed);
      } catch (e) {
        formattedDate = slotDate.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassPane(
        onTap: () {
          // Note: Details screen will currently only show details for the *first* booking in the group.
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
        child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('turfs').doc(turfId).get(),
            builder: (context, snapshot) {

              String displayTurfName = initialTurfName;
              String displayTurfImage = "https://i.ibb.co/vJkFq7k/no-image.jpg";

              if (snapshot.hasData && snapshot.data!.exists) {
                final turfData = snapshot.data!.data() as Map<String, dynamic>;
                if (turfData['turf_name'] != null) displayTurfName = turfData['turf_name'];
                if (turfData['images'] != null && (turfData['images'] as List).isNotEmpty) {
                  displayTurfImage = turfData['images'][0];
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayTurfName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(slot, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                        if (amountPaid != null) ...[
                          const SizedBox(height: 4),
                          Text("₹$amountPaid", style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatusChip(status),
                            const Spacer(),
                            const Text("Details >", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      displayTurfImage, width: 80, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
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
      case "cancelled": color = Colors.redAccent; label = "Cancelled"; break;
      case "pending": color = Colors.orangeAccent; label = "Pending"; break;
      default: color = Colors.greenAccent; label = "Confirmed";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _GlassPane extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPane({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(12), child: child))),
    );
  }
}