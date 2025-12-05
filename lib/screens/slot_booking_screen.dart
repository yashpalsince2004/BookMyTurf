import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/turf_slot.dart';
import 'booking/confirm_booking_screen.dart';

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
  // Theme Colors
  final Color backgroundColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00E676);
  // ✅ Changed to a light, semi-transparent red for a "glass tint" effect
  final Color bookedColor = const Color(0x80EF5350);
  final Color weekendColor = const Color(0xFFFF9800);
  final Color calendarSelectedColor = const Color(0xFF4CAF50);

  List<TurfSlot> allSlots = [];
  List<DateTime> dateList = [];
  DateTime _selectedDate = DateTime.now();
  List<String> selectedSlots = [];
  bool loading = true;

  int priceMorning = 0;
  int priceAfternoon = 0;
  int priceEvening = 0;
  int priceNight = 0;
  String openTimeStr = "06:00";
  String closeTimeStr = "23:00";
  String turfAddress = "Loading address...";
  String turfOwnerId = "";

  @override
  void initState() {
    super.initState();
    _generateDates();
    _fetchTurfData();
  }

  void _generateDates() {
    final now = DateTime.now();
    dateList = List.generate(14, (index) => now.add(Duration(days: index)));
  }

  Future<void> _fetchTurfData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .get();

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          priceMorning = int.tryParse(data['price_morning'].toString()) ?? 0;
          priceAfternoon = int.tryParse(data['price_afternoon'].toString()) ?? 0;
          priceEvening = int.tryParse(data['price_evening'].toString()) ?? 0;
          priceNight = int.tryParse(data['price_night'].toString()) ?? 0;
          openTimeStr = data['open_time'] ?? "06:00";
          closeTimeStr = data['close_time'] ?? "23:00";
          turfAddress = data['address'] ?? "Location details not available";
          turfOwnerId = data['ownerId'] ?? "";

          _generateSlots();
        });
        _listenToBookings();
      }
    } catch (e) {
      debugPrint("Error fetching turf data: $e");
      _generateSlots();
    }
  }

  void _generateSlots() {
    allSlots.clear();
    int openHour = int.parse(openTimeStr.split(":")[0]);
    int closeHour = int.parse(closeTimeStr.split(":")[0]);
    if (closeHour <= openHour) closeHour += 24;

    for (int i = openHour; i < closeHour; i++) {
      int currentHour = i % 24;
      TimeOfDay start = TimeOfDay(hour: currentHour, minute: 0);
      int nextHour = (currentHour + 1) % 24;
      TimeOfDay end = TimeOfDay(hour: nextHour, minute: 0);
      String timeString = "${_formatTime(start)} - ${_formatTime(end)}";

      int currentPrice = priceNight;
      if (currentHour >= 6 && currentHour < 12) currentPrice = priceMorning;
      else if (currentHour >= 12 && currentHour < 17) currentPrice = priceAfternoon;
      else if (currentHour >= 17 && currentHour < 22) currentPrice = priceEvening;

      allSlots.add(TurfSlot(time: timeString, isAvailable: true, price: currentPrice));
    }
    setState(() => loading = false);
  }

  void _listenToBookings() {
    // Ensure date format matches your DB (dd/MM/yyyy)
    String dateKey = DateFormat('dd/MM/yyyy').format(_selectedDate);

    FirebaseFirestore.instance
        .collection("bookings")
        .where("turf_id", isEqualTo: widget.turfId)
        .where("slot_date", isEqualTo: dateKey)
        .snapshots()
        .listen((snapshot) {

      final List<String> bookedTimes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data["status"] == "cancelled") continue;

        // 1. Check for the new List format (Merged Slots)
        if (data['slots'] != null && data['slots'] is List) {
          var list = List<String>.from(data['slots']);
          bookedTimes.addAll(list);
        }
        // 2. Check for the old String format (Legacy/Single Slots)
        else if (data['slot'] != null) {
          bookedTimes.add(data['slot'].toString());
        }
      }

      if (mounted) {
        setState(() {
          final toRemove = <String>[];
          for (var slot in allSlots) {
            // Mark as unavailable if found in bookings
            slot.isAvailable = !bookedTimes.contains(slot.time);

            // If currently selected but now booked by someone else, remove selection
            if (!slot.isAvailable && selectedSlots.contains(slot.time)) {
              toRemove.add(slot.time);
            }
          }
          selectedSlots.removeWhere((s) => toRemove.contains(s));
        });
      }
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  void _bookSlots() {
    if (selectedSlots.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please sign in.")));
      return;
    }

    int total = 0;
    Map<String, int> slotPriceMap = {};
    for (String slotTime in selectedSlots) {
      var slotObj = allSlots.firstWhere((s) => s.time == slotTime);
      total += slotObj.price;
      slotPriceMap[slotTime] = slotObj.price;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmBookingScreen(
          turfId: widget.turfId,
          turfName: widget.turfName,
          turfImage: widget.turfImage,
          turfAddress: turfAddress,
          turfOwnerId: turfOwnerId,
          date: _selectedDate,
          selectedSlots: List.from(selectedSlots),
          slotPrices: slotPriceMap,
          totalPrice: total,
        ),
      ),
    );
  }

  Map<String, List<TurfSlot>> _categorizeSlots(List<TurfSlot> slots) {
    List<TurfSlot> morning = [];
    List<TurfSlot> afternoon = [];
    List<TurfSlot> evening = [];
    List<TurfSlot> night = [];

    for (var slot in slots) {
      try {
        String startTime = slot.time.split(" - ")[0];
        bool isPm = startTime.contains("PM");
        int hour = int.parse(startTime.split(":")[0]);

        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        if (hour >= 6 && hour < 12) morning.add(slot);
        else if (hour >= 12 && hour < 17) afternoon.add(slot);
        else if (hour >= 17 && hour < 22) evening.add(slot);
        else night.add(slot);
      } catch (e) {
        evening.add(slot);
      }
    }
    return { "Morning": morning, "Afternoon": afternoon, "Evening": evening, "Night": night };
  }

  int _calculateTotalSelectionPrice() {
    int total = 0;
    for (String time in selectedSlots) {
      var slot = allSlots.firstWhere((s) => s.time == time);
      total += slot.price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final categorized = _categorizeSlots(allSlots);
    final totalSelectionPrice = _calculateTotalSelectionPrice();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(widget.turfName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(widget.turfImage),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  Container(
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: accentColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            turfAddress,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text("Select Date", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),

                  SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: dateList.length,
                      itemBuilder: (context, index) {
                        final date = dateList[index];
                        final isSelected = DateUtils.isSameDay(date, _selectedDate);
                        final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

                        Color bg = isSelected ? calendarSelectedColor : (isWeekend ? weekendColor.withOpacity(0.15) : cardColor);
                        Color border = isSelected ? Colors.transparent : (isWeekend ? weekendColor.withOpacity(0.4) : Colors.white.withOpacity(0.1));
                        Color textC = isWeekend && !isSelected ? weekendColor : Colors.white;
                        Color subTextC = isWeekend && !isSelected ? weekendColor.withOpacity(0.7) : Colors.white54;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              selectedSlots.clear();
                            });
                            _listenToBookings();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 65,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subTextC)),
                                const SizedBox(height: 6),
                                Text("${date.day}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textC)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildSectionUI("Morning", categorized["Morning"]!, priceMorning),
                        _buildSectionUI("Afternoon", categorized["Afternoon"]!, priceAfternoon),
                        _buildSectionUI("Evening", categorized["Evening"]!, priceEvening),
                        _buildSectionUI("Night", categorized["Night"]!, priceNight),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomSheet: selectedSlots.isNotEmpty ? Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _bookSlots,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Book ${selectedSlots.length} Slot(s)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: Colors.black54),
                const SizedBox(width: 10),
                Text("₹$totalSelectionPrice", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))
              ],
            ),
          ),
        ),
      ) : null,
    );
  }

  // --- REUSABLE SECTION BUILDER ---
  Widget _buildSectionUI(String title, List<TurfSlot> slots, int sectionPrice) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Icon(
                title == "Morning"
                    ? Icons.wb_sunny_outlined
                    : title == "Afternoon"
                    ? Icons.wb_sunny
                    : title == "Evening"
                    ? Icons.wb_twilight
                    : Icons.nightlight_round,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                "(₹$sectionPrice)",
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isSelected = selectedSlots.contains(slot.time);
            final isAvailable = slot.isAvailable;

            Color bg = cardColor;
            Color border = Colors.white12;
            Color text = Colors.white;

            if (!isAvailable) {
              bg = bookedColor;
              border = bookedColor;
              text = Colors.white70;
            } else if (isSelected) {
              bg = accentColor.withOpacity(0.2);
              border = accentColor;
              text = accentColor;
            }

            return GestureDetector(
              onTap: isAvailable
                  ? () {
                setState(() {
                  // ⚡️ CONSECUTIVE SELECTION LOGIC ⚡️

                  // 1. Find the master index of this slot in the full list
                  int tappedIndex = allSlots.indexOf(slot);

                  if (selectedSlots.contains(slot.time)) {
                    // --- DESELECTION LOGIC ---
                    // Get indices of all currently selected slots
                    List<int> currentIndices = selectedSlots
                        .map((t) => allSlots.indexWhere((s) => s.time == t))
                        .toList()..sort();

                    // Allow removal only if it's the FIRST or LAST slot in the chain
                    if (tappedIndex == currentIndices.first || tappedIndex == currentIndices.last) {
                      selectedSlots.remove(slot.time);
                    } else {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Can't remove middle slot. Unselect from edges."),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 1),
                          )
                      );
                    }
                  } else {
                    // --- SELECTION LOGIC ---
                    if (selectedSlots.isEmpty) {
                      // First slot is always free to pick
                      selectedSlots.add(slot.time);
                    } else {
                      // Get min and max indices of current selection
                      List<int> currentIndices = selectedSlots
                          .map((t) => allSlots.indexWhere((s) => s.time == t))
                          .toList()..sort();

                      int minIndex = currentIndices.first;
                      int maxIndex = currentIndices.last;

                      // Check if the tapped slot is exactly before First OR after Last
                      if (tappedIndex == minIndex - 1 || tappedIndex == maxIndex + 1) {
                        selectedSlots.add(slot.time);
                      } else {
                        // Invalid Selection (Gap)
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select back-to-back slots only."),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 2),
                            )
                        );
                      }
                    }
                  }
                });
              }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  slot.time.split(" - ")[0],
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: !isAvailable ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}