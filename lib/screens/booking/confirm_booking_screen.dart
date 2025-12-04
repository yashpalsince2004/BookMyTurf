import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final String turfId;
  final String turfName;
  final String turfImage;
  final String turfAddress;
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
  // 🔒 Payment is always UPI now
  final String _paymentMethod = "UPI";

  // Payment Option State
  bool _isFullPayment = true; // Default to Full Payment

  // Theme Colors
  final Color backgroundColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00E676);
  final Color partialColor = const Color(0xFFFF9800);

  Future<void> _processPaymentAndBook() async {
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    String dateKey = DateFormat('yyyy-MM-dd').format(widget.date);

    // Calculate amounts
    int payableNow = _isFullPayment ? widget.totalPrice : (widget.totalPrice / 2).ceil();
    int balanceAtVenue = widget.totalPrice - payableNow;
    String paymentTypeStr = _isFullPayment ? "Full Payment" : "Partial Payment";

    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulate UPI Payment

      for (String slotTime in widget.selectedSlots) {
        int thisSlotPrice = widget.slotPrices[slotTime] ?? 0;

        String docId = "${widget.turfId}_${dateKey}_${slotTime.replaceAll(' ', '')}";
        DocumentReference docRef = firestore.collection("bookings").doc(docId);

        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          if (data["status"] != "cancelled") {
            throw Exception("Slot $slotTime was just taken! Please try again.");
          }
        }

        batch.set(
          docRef,
          {
            "turfId": widget.turfId,
            "turfName": widget.turfName,
            "turfImage": widget.turfImage,
            "turfAddress": widget.turfAddress,
            "slot": slotTime,
            "date": dateKey,
            "price": thisSlotPrice,
            "userId": currentUser?.uid,
            "userName": currentUser?.displayName ?? currentUser?.phoneNumber ?? "Player",
            "timestamp": FieldValue.serverTimestamp(),
            "status": "confirmed",

            // Payment Fields
            "paymentMethod": _paymentMethod, // Always UPI
            "paymentType": paymentTypeStr,
            "totalAmount": widget.totalPrice,
            "amountPaid": payableNow,
            "balanceAmount": balanceAtVenue,
            "paymentStatus": "advance_paid", // Since they always pay something now
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

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
            // 1. Turf Summary Card
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

            // 2. Booking Details
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

            // 3. Payment Options (Full vs Partial)
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
                    // 🆕 Updated Text
                    subtitle: "Balance payable at venue 10 min before slot",
                    value: false,
                    price: (widget.totalPrice / 2).ceil(),
                    isPartial: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Payment Summary
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
                      Text("Payable Now (UPI)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // 5. Static Payment Method Info (Since it's only UPI)
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

      // Bottom Pay Button
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

  // Helper for Payment Options
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