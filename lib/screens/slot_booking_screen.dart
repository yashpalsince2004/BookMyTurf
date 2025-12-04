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
  // --- THEME COLORS ---
  final Color backgroundColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00E676);
  final Color bookedColor = const Color(0xFFFF5252);
  final Color weekendColor = const Color(0xFFFF9800);
  final Color calendarSelectedColor = const Color(0xFF4CAF50);

  List<TurfSlot> allSlots = [];

  // Date State
  List<DateTime> dateList = [];
  DateTime _selectedDate = DateTime.now();

  // Selection State
  List<String> selectedSlots = [];
  bool loading = true;

  // --- DYNAMIC DATA ---
  int priceMorning = 0;
  int priceAfternoon = 0;
  int priceEvening = 0;
  int priceNight = 0;

  String openTimeStr = "06:00";
  String closeTimeStr = "23:00";

  // Address Field
  String turfAddress = "Loading address...";

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

  // --- FETCH DATA ---
  Future<void> _fetchTurfData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .get();

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          // Fetch Prices
          priceMorning = int.tryParse(data['price_morning'].toString()) ?? 0;
          priceAfternoon = int.tryParse(data['price_afternoon'].toString()) ?? 0;
          priceEvening = int.tryParse(data['price_evening'].toString()) ?? 0;
          priceNight = int.tryParse(data['price_night'].toString()) ?? 0;

          // Fetch Hours
          openTimeStr = data['open_time'] ?? "06:00";
          closeTimeStr = data['close_time'] ?? "23:00";

          // Fetch Address
          turfAddress = data['address'] ?? "Location details not available";

          _generateSlots();
        });

        _listenToBookings();
      }
    } catch (e) {
      debugPrint("Error fetching turf data: $e");
      _generateSlots();
    }
  }

  // --- SLOT GENERATOR ---
  void _generateSlots() {
    allSlots.clear();

    int openHour = int.parse(openTimeStr.split(":")[0]);
    int closeHour = int.parse(closeTimeStr.split(":")[0]);

    if (closeHour <= openHour) {
      closeHour += 24;
    }

    for (int i = openHour; i < closeHour; i++) {
      int currentHour = i % 24;

      TimeOfDay start = TimeOfDay(hour: currentHour, minute: 0);
      int nextHour = (currentHour + 1) % 24;
      TimeOfDay end = TimeOfDay(hour: nextHour, minute: 0);

      String timeString = "${_formatTime(start)} - ${_formatTime(end)}";

      int currentPrice = priceNight;

      if (currentHour >= 6 && currentHour < 12) {
        currentPrice = priceMorning;
      } else if (currentHour >= 12 && currentHour < 17) {
        currentPrice = priceAfternoon;
      } else if (currentHour >= 17 && currentHour < 22) {
        currentPrice = priceEvening;
      } else {
        currentPrice = priceNight;
      }

      allSlots.add(
        TurfSlot(
          time: timeString,
          isAvailable: true,
          price: currentPrice,
        ),
      );
    }

    setState(() {
      loading = false;
    });
  }

  // --- FIRESTORE LISTENER ---
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

      if (mounted) {
        setState(() {
          final toRemove = <String>[];
          for (var slot in allSlots) {
            slot.isAvailable = !bookedTimes.contains(slot.time);
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

  // --- UPDATED NAVIGATION LOGIC ---
  void _bookSlots() {
    if (selectedSlots.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Please sign in to book slots."), backgroundColor: bookedColor),
      );
      return;
    }

    // 1. Calculate Total Price & Prepare Price Map
    int total = 0;
    Map<String, int> slotPriceMap = {};

    for (String slotTime in selectedSlots) {
      // Find the slot object from allSlots to get its specific price
      var slotObj = allSlots.firstWhere((s) => s.time == slotTime);
      total += slotObj.price;
      slotPriceMap[slotTime] = slotObj.price;
    }

    // 2. Navigate to Confirm Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmBookingScreen(
          turfId: widget.turfId,
          turfName: widget.turfName,
          turfImage: widget.turfImage,
          turfAddress: turfAddress, // This variable is already in your state
          date: _selectedDate,
          selectedSlots: List.from(selectedSlots), // Send a copy of the list
          slotPrices: slotPriceMap,
          totalPrice: total,
        ),
      ),
    );
  }

  // --- CATEGORIZE SLOTS ---
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

        if (hour >= 6 && hour < 12) {
          morning.add(slot);
        } else if (hour >= 12 && hour < 17) {
          afternoon.add(slot);
        } else if (hour >= 17 && hour < 22) {
          evening.add(slot);
        } else {
          night.add(slot);
        }
      } catch (e) {
        evening.add(slot);
      }
    }
    return {
      "Morning": morning,
      "Afternoon": afternoon,
      "Evening": evening,
      "Night": night,
    };
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
        title: Text(widget.turfName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  // 1. Turf Image (Gradient REMOVED)
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

                  // 2. Address Section (Simple Row)
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

                  // 3. Date Selector Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text("Select Date",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),

                  // 4. Date Selector List
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

                        Color bg = isSelected ? calendarSelectedColor :
                        (isWeekend ? weekendColor.withOpacity(0.15) : cardColor);
                        Color border = isSelected ? Colors.transparent :
                        (isWeekend ? weekendColor.withOpacity(0.4) : Colors.white.withOpacity(0.1));
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
                                Text(DateFormat('EEE').format(date).toUpperCase(),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subTextC)),
                                const SizedBox(height: 6),
                                Text("${date.day}",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textC)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 5. Scrollable Sections (Morning -> Night)
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

      // Floating Booking Bar
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
                Text(
                  "Book ${selectedSlots.length} Slot(s)",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: Colors.black54),
                const SizedBox(width: 10),
                Text(
                  "₹$totalSelectionPrice",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                )
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
              bg = bookedColor.withOpacity(0.1);
              border = bookedColor.withOpacity(0.3);
              text = bookedColor.withOpacity(0.6);
            } else if (isSelected) {
              bg = accentColor.withOpacity(0.2);
              border = accentColor;
              text = accentColor;
            }

            return GestureDetector(
              onTap: isAvailable
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