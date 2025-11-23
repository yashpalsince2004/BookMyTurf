import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/turf_slot.dart';

class SlotBookingScreen extends StatefulWidget {
  final String turfName;
  final String turfId; // Important for Firestore path

  const SlotBookingScreen({
    super.key,
    required this.turfName,
    required this.turfId,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  String? selectedSlot;
  final user = FirebaseAuth.instance.currentUser;
  late String today;

  @override
  void initState() {
    today = DateTime.now().toString().substring(0, 10); // yyyy-mm-dd format
    super.initState();
  }

  /// Fetch live slots from Firestore
  Stream<List<TurfSlot>> getSlotsStream() {
    return FirebaseFirestore.instance
        .collection("turfs")
        .doc(widget.turfId)
        .collection("slots")
        .doc(today)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {};
      return data.entries
          .map((entry) => TurfSlot.fromMap(entry.key, entry.value))
          .toList();
    });
  }

  /// Book selected slot in Firestore
  Future<void> bookSlot(String time) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    final slotRef = FirebaseFirestore.instance
        .collection("turfs")
        .doc(widget.turfId)
        .collection("slots")
        .doc(today);

    await slotRef.update({
      "$time.available": false,
      "$time.bookedBy": user!.uid,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✔ Slot Confirmed: $time")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Slots - ${widget.turfName}"),
        backgroundColor: Colors.green,
      ),

      body: StreamBuilder<List<TurfSlot>>(
        stream: getSlotsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          }

          final slots = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];

                    return GestureDetector(
                      onTap: slot.isAvailable
                          ? () => setState(() => selectedSlot = slot.time)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: slot.isAvailable
                              ? (selectedSlot == slot.time
                              ? Colors.green.shade300
                              : Colors.white)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedSlot == slot.time
                                ? Colors.green
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(slot.time,
                                style: const TextStyle(fontSize: 16)),
                            Text(
                              slot.isAvailable
                                  ? "₹${slot.price}"
                                  : (slot.bookedBy == user?.uid
                                  ? "✔ Booked by You"
                                  : "Booked"),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slot.isAvailable
                                    ? Colors.green
                                    : (slot.bookedBy == user?.uid
                                    ? Colors.blue
                                    : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Confirm Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: selectedSlot == null
                      ? null
                      : () async {
                    await bookSlot(selectedSlot!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedSlot == null
                        ? Colors.grey
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                  const Text("Confirm Booking", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
