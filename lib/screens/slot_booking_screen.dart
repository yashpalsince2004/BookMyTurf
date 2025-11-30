import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add this to pubspec.yaml for date formatting
import '../models/turf_slot.dart';

class SlotBookingScreen extends StatefulWidget {
  final String turfId;
  final String turfName;
  final String turfImage;

  const SlotBookingScreen({
    super.key,
    required this.turfId,
    required this.turfName,
    required this.turfImage,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  List<TurfSlot> allSlots = [];
  List<TurfSlot> displayedSlots = [];

  // Date State
  List<DateTime> dateList = [];
  DateTime _selectedDate = DateTime.now();

  // Selection State
  List<String> selectedSlots = [];

  bool loading = true;
  final int _slotPrice = 600;

  final List<String> _sections = ["Morning", "Afternoon", "Evening"];

  String _selectedSection = "Morning";

  @override
  void initState() {
    super.initState();
    _generateDates();
    _generateSlots();
    _listenToBookings();
  }

  void _generateDates() {
    final now = DateTime.now();
    dateList = List.generate(14, (index) => now.add(Duration(days: index)));
  }

  void _generateSlots() {
    allSlots.clear();
    // Generate slots from 6:00 AM to 11:00 PM
    for (int hour = 6; hour < 23; hour++) {
      final start = TimeOfDay(hour: hour, minute: 0);
      final end = TimeOfDay(hour: hour + 1, minute: 0);

      // We use the start time as a clean ID for logic (e.g., "06:00 AM")
      String timeString = "${_formatTime(start)} - ${_formatTime(end)}";

      allSlots.add(
        TurfSlot(
          time: timeString,
          isAvailable: true,
          price: _slotPrice,
        ),
      );
    }
    loading = false;
    _filterSlots();
  }

  // --- 🔥 CORE FIRESTORE LISTENER ---
  void _listenToBookings() {
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    FirebaseFirestore.instance
        .collection("bookings")
        .where("turfId", isEqualTo: widget.turfId)
        .where("date", isEqualTo: dateKey)
        .snapshots()
        .listen((snapshot) {

      final bookedTimes = snapshot.docs
          .where((doc) => doc["status"] != "cancelled")
          .map((doc) => doc["slot"].toString())
          .toList();

      setState(() {
        final toRemove = <String>[];

        for (var slot in allSlots) {
          slot.isAvailable = !bookedTimes.contains(slot.time);

          if (!slot.isAvailable && selectedSlots.contains(slot.time)) {
            toRemove.add(slot.time);
          }
        }

        // SAFE removal
        selectedSlots.removeWhere((s) => toRemove.contains(s));

        _filterSlots();
      });
    });
  }



  void _filterSlots() {
    setState(() {
      displayedSlots = allSlots.where((slot) {
        String timeStr = slot.time.split(" - ")[0];
        int hour = int.parse(timeStr.split(":")[0]);
        bool isPM = timeStr.contains("PM");

        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;

        if (_selectedSection == "Morning") return hour >= 6 && hour < 12;
        if (_selectedSection == "Afternoon") return hour >= 12 && hour < 17;
        return hour >= 17;
      }).toList();
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }
  // _______________________________________
  // --- 🔥 CORE BOOKING LOGIC ---
  //_________________________________________
  Future<void> _bookSlots() async {
    if (selectedSlots.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Not logged in — show message and return
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to book slots.")),
      );
      return;
    }

    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      final List<String> slotsToBook = List.from(selectedSlots);

      for (String slotTime in slotsToBook) {
        String docId = "${widget.turfId}_${dateKey}_${slotTime.replaceAll(' ', '')}";

        DocumentReference docRef =
        FirebaseFirestore.instance.collection("bookings").doc(docId);

        final snap = await docRef.get();

        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final status = data["status"] ?? "confirmed";

          // If it's cancelled, treat slot as FREE
          if (status != "cancelled") {
            throw Exception("Slot $slotTime is already booked!");
          }
        }


        batch.set(docRef, {
          "turfId": widget.turfId,
          "turfName": widget.turfName,
          "turfImage": widget.turfImage,
          "slot": slotTime,
          "date": dateKey,
          "price": _slotPrice,
          "userId": currentUser.uid,
          "userName": currentUser.displayName ?? currentUser.phoneNumber ?? "Player",
          "timestamp": FieldValue.serverTimestamp(),
          "status": "confirmed",
        },
        SetOptions(merge: true));
      }

      // Only after loop completes
      selectedSlots.clear();


      // commit only if there is something to write
      if (batch.commit != null) {
        await batch.commit();
      }

      if (!mounted) return;
      Navigator.pop(context); // remove loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking Confirmed!"), backgroundColor: Colors.green),
      );

      setState(() {
        selectedSlots.clear();
      });

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // remove loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking Failed: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(widget.turfName),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turf Image
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(widget.turfImage),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Date Selector
          Container(
            height: 90,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: dateList.length,
              itemBuilder: (context, index) {
                final date = dateList[index];
                final isSelected = DateUtils.isSameDay(date, _selectedDate);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      selectedSlots.clear();
                    });
                    _listenToBookings();
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE').format(date).toUpperCase(),
                            style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey)),
                        const SizedBox(height: 4),
                        Text("${date.day}",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM').format(date).toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Section Dropdown
          // 🔁 REPLACE YOUR CURRENT "Section Dropdown" BLOCK WITH THIS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _sections.map((section) {
                  final bool isSelected = section == _selectedSection;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(right: 12),
                    padding: EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: isSelected ? 26 : 18, // stretch effect
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedSection = section);
                        _filterSlots();
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Row(
                        children: [
                          if (isSelected)
                            const Icon(Icons.check, color: Colors.white, size: 18),
                          if (isSelected) const SizedBox(width: 6),
                          Text(
                            section,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),




          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text("Available Slots", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          // Slot Grid
          Expanded(
            child: displayedSlots.isEmpty
                ? const Center(child: Text("No slots available"))
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: displayedSlots.length,
              itemBuilder: (context, index) {
                final slot = displayedSlots[index];
                final isSelected = selectedSlots.contains(slot.time);

                return GestureDetector(
                  onTap: slot.isAvailable
                      ? () {
                    setState(() {
                      if (selectedSlots.contains(slot.time)) {
                        selectedSlots.remove(slot.time);
                      } else {
                        selectedSlots.add(slot.time);
                      }
                    });
                  }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: slot.isAvailable
                          ? (isSelected ? Colors.green : Colors.white)
                          : Colors.grey.shade300,
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      slot.time.split(" - ")[0],
                      style: TextStyle(
                        color: slot.isAvailable
                            ? (isSelected ? Colors.white : Colors.black87)
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: !slot.isAvailable ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Sheet / Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: selectedSlots.isNotEmpty ? _bookSlots : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectedSlots.isEmpty
                        ? "Select Slots"
                        : "Book ${selectedSlots.length} Slot${selectedSlots.length > 1 ? 's' : ''}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (selectedSlots.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(width: 1, height: 20, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      "₹${selectedSlots.length * _slotPrice}",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}