import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final String turfId;
  final String turfName;
  final String turfImage;
  final String turfAddress;
  final String turfOwnerId;
  final DateTime date;
  final List<String> selectedSlots;
  final Map<String, int> slotPrices;
  final int totalPrice;

  const ConfirmBookingScreen({
    super.key,
    required this.turfId,
    required this.turfName,
    required this.turfImage,
    required this.turfAddress,
    required this.turfOwnerId,
    required this.date,
    required this.selectedSlots,
    required this.slotPrices,
    required this.totalPrice,
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  bool _isLoading = false;
  // ignore: unused_field
  final String _paymentMethod = "UPI";
  bool _isFullPayment = true;

  final Color backgroundColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00E676);
  final Color partialColor = const Color(0xFFFF9800);

  // ✅ UPDATED FUNCTION: Creates 1 Single Merged Document
  Future<void> _processPaymentAndBook() async {
    if (widget.selectedSlots.isEmpty) return;

    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    // Date Format: DD/MM/YYYY
    String slotDateFormatted = DateFormat('dd/MM/yyyy').format(widget.date);

    // Calculate Financials
    int payableNow = _isFullPayment ? widget.totalPrice : (widget.totalPrice / 2).ceil();
    int balanceAmount = widget.totalPrice - payableNow;

    // 1. Sort Slots (Ensure "6-7, 7-8" order)
    List<String> sortedSlots = List.from(widget.selectedSlots)..sort();

    // 2. Create Display String (e.g., "6:00 AM - 9:00 AM")
    String startTime = sortedSlots.first.split('-')[0].trim();
    String endTime = sortedSlots.last.split('-')[1].trim();
    String displaySlotRange = "$startTime - $endTime";

    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulate payment delay

      // 3. Prepare ONE Data Object (No Loop!)
      Map<String, dynamic> bookingData = {
        // --- KEY FIX: Save as List AND String ---
        "slots": sortedSlots,           // List ["6:00 AM - 7:00 AM", "7:00 AM..."]
        // "slot_display": displaySlotRange, // String "6:00 AM - 9:00 AM"
        "slot": displaySlotRange,       // Legacy support

        // Turf & Owner Details
        "turf_id": widget.turfId,
        "turf_name": widget.turfName,
        "owner_id": widget.turfOwnerId,

        // User Details
        "user_id": currentUser?.uid,
        "booked_by": "user",
        "user_phone": currentUser?.phoneNumber ?? "Unknown",
        "customer_phone": currentUser?.phoneNumber ?? "Unknown",

        // Financials (Aggregated)
        "amount_total": widget.totalPrice,
        "amount_paid": payableNow,
        "amount_balance": balanceAmount,
        "payment_method": "UPI",

        // Meta Data
        "slot_date": slotDateFormatted,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "confirmed",
      };

      // 4. Write Single Document to Firestore
      await firestore.collection("bookings").add(bookingData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Booking Confirmed! Payment Successful."), backgroundColor: accentColor),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int payableAmount = _isFullPayment ? widget.totalPrice : (widget.totalPrice / 2).ceil();
    int balanceAmount = widget.totalPrice - payableAmount;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text("Confirm Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.turfImage, width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.turfName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(widget.turfAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text("Booking Details", style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _rowDetail("Date", DateFormat("d MMM, yyyy").format(widget.date)),
                  const Divider(color: Colors.white10),
                  _rowDetail("Slots", "${widget.selectedSlots.length} Selected"),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.selectedSlots.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: Text(s.split(" - ")[0], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    )).toList(),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text("Choose Payment Option", style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildRadioOption(
                    title: "Full Payment (100%)",
                    subtitle: "Pay complete amount now via UPI",
                    value: true,
                    price: widget.totalPrice,
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildRadioOption(
                    title: "Partial Payment (50%)",
                    subtitle: "Balance payable at venue 10 min before slot",
                    value: false,
                    price: (widget.totalPrice / 2).ceil(),
                    isPartial: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text("Payment Summary", style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _rowDetail("Total Amount", "₹${widget.totalPrice}"),
                  const Divider(color: Colors.white10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Payable Now (UPI)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("₹$payableAmount", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),

                  if (balanceAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Balance at Venue", style: TextStyle(color: Colors.white70)),
                        Text("₹$balanceAmount", style: TextStyle(color: partialColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "* Pay balance 10 min before slot begins",
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: accentColor, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Online payment is securely processed via UPI.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: cardColor,
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _processPaymentAndBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(
                "Pay ₹$payableAmount via UPI",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption({required String title, required String subtitle, required bool value, required int price, bool isPartial = false}) {
    bool isSelected = _isFullPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _isFullPayment = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? (isPartial ? partialColor : accentColor) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Text("₹$price", style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _rowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}