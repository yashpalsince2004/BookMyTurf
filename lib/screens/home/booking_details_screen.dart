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
    final turfName = bookingData["turfName"];
    final turfImage = bookingData["turfImage"] ?? "https://i.ibb.co/vJkFq7k/no-image.jpg";
    final price = bookingData["price"];
    final slot = bookingData["slot"];
    final date = bookingData["date"];
    final status = bookingData["status"] ?? "confirmed";

    final formattedDate =
    DateFormat("dd MMM yyyy").format(DateTime.parse(date));

    return Scaffold(
      backgroundColor: const Color(0xffF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Booking Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Turf Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                turfImage,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 16),

            // Turf Name
            Text(
              turfName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Status Chip
            _buildStatusChip(status),

            const SizedBox(height: 18),

            // Date
            Text(
              "Date",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 18),

            // Slot
            Text(
              "Time Slot",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            Text(
              slot,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 18),

            // Price
            Text(
              "Price",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            Text(
              "₹$price",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 30),

            // CANCEL BUTTON
            if (status != "cancelled")
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _cancelBooking(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Cancel Booking",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------- CANCEL BOOKING ---------------------

  void _cancelBooking(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Cancel Booking?"),
        content:
        const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection("bookings")
        .doc(bookingId)
        .update({"status": "cancelled"});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Booking Cancelled!"),
        backgroundColor: Colors.red,
      ),
    );

    Navigator.pop(context);
  }

  // Chip
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
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
