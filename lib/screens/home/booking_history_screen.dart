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
        appBar: AppBar(
          title: const Text("My Bookings"),
          backgroundColor: Colors.green,
        ),
        body: const Center(child: Text("Please login to view bookings.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF7F6FB),
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .where("userId", isEqualTo: userId)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return const Center(
              child: Text("No bookings yet.",
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;

              final turfName = data["turfName"] ?? "";
              final slot = data["slot"] ?? "";
              final price = data["price"] ?? 0;
              final date = data["date"];
              final status = data["status"] ?? "confirmed";
              final turfImage = data["turfImage"] ?? "https://i.ibb.co/vJkFq7k/no-image.jpg";



              final formattedDate = DateFormat("dd MMM yyyy").format(DateTime.parse(date));

              return GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // ----- Left: TEXT INFO -----
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              turfName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            Text("Slot: $slot",
                                style:
                                const TextStyle(fontSize: 14, color: Colors.black87)),
                            Text("Date: $formattedDate",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black54)),
                            const SizedBox(height: 8),
                            _buildStatusChip(status),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingDetailsScreen(
                                      bookingData: data,
                                      bookingId: bookings[index].id,
                                    ),
                                  ),
                                );
                              },

                              child: const Text(
                                "More detail",
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            )
                          ],
                        ),
                      ),

                      // ----- Right: IMAGE -----
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          turfImage,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;

    switch (status) {
      case "cancelled":
        color = Colors.red;
        break;
      case "pending":
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
