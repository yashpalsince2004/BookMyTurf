import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bookmyturf/widgets/floating_nav_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:math'; // Added for min() function
import 'package:bookmyturf/widgets/glass_pane.dart';
import 'package:bookmyturf/models/turf_models.dart';
import '../city_picker_screen.dart';
import '../like_screen.dart';
import '../slot_booking_screen.dart';

// ---------------------------------------------
// HOME SCREEN
// ---------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? currentCity;
  String? _filterCity; // Stores "Kalyan" for DB filtering
  int _selectedIndex = 0;

  List<String> _favoriteTurfIds = [];
  StreamSubscription<DocumentSnapshot>? _favSubscription;

  @override
  void initState() {
    super.initState();
    _askLocationPermission();
    _fetchLocation();
    _listenToFavorites();
    _ensureUserDocumentExists();
  }

  Future<void> _ensureUserDocumentExists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          await userDocRef.set({
            'uid': user.uid,
            'email': user.email ?? 'No Email',
            'phone': user.phoneNumber ?? 'No Phone',
            'name': user.displayName ?? 'New Player',
            'createdAt': FieldValue.serverTimestamp(),
            'favTurf': [],
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("🔥 FIRESTORE ERROR: $e");
    }
  }

  @override
  void dispose() {
    _favSubscription?.cancel();
    super.dispose();
  }

  void _listenToFavorites() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _favSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('favTurf')) {
            setState(() {
              _favoriteTurfIds = List<String>.from(data['favTurf']);
            });
          }
        }
      });
    }
  }

  Future<void> _toggleFavorite(String turfId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to save favorites!")),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    HapticFeedback.mediumImpact();

    if (_favoriteTurfIds.contains(turfId)) {
      await userRef.update({
        'favTurf': FieldValue.arrayRemove([turfId])
      });
    } else {
      await userRef.set({
        'favTurf': FieldValue.arrayUnion([turfId])
      }, SetOptions(merge: true));
    }
  }

  Future<void> _fetchLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (mounted) {
          setState(() {
            _filterCity = place.locality;
            currentCity = "${place.locality}, ${place.administrativeArea}";
          });
        }
      }
    } catch (e) {
      print("Location Error: $e");
    }
  }

  final List<SportCategory> _categories = [
    SportCategory('Football', Icons.sports_soccer, Colors.greenAccent),
    SportCategory('Cricket', Icons.sports_cricket, Colors.lightBlueAccent),
    SportCategory('Badminton', Icons.sports_tennis, Colors.orangeAccent),
    SportCategory('Tennis', Icons.sports_tennis_outlined, Colors.redAccent),
    SportCategory('Basketball', Icons.sports_basketball, Colors.deepOrangeAccent),
  ];

  Future<void> _askLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/turf_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),

          // 2. SCROLLABLE CONTENT
          CustomScrollView(
            cacheExtent: 800,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- Glass App Bar ---
              SliverAppBar(
                floating: true,
                pinned: true,
                toolbarHeight: 90,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final selectedCity = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CityPickerScreen()),
                        );
                        if (selectedCity != null) {
                          setState(() {
                            currentCity = selectedCity;
                            _filterCity = selectedCity.split(',')[0].trim();
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.greenAccent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              currentCity ?? "Locating...",
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        String name = "Player";
                        if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
                          name = user.displayName!.split(" ").first;
                        }
                        return Text(
                          "Hello, $name 👋",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  Stack(
                    children: [
                      GlassPane(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 12,
                        useBlur: true,
                        onTap: () {},
                        child: const Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green,
                      backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=Yash"),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GlassPane(
                      padding: EdgeInsets.zero,
                      borderRadius: 16,
                      useBlur: true,
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search "Cricket Turf"',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.tune, color: Colors.white, size: 18),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Categories ---
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          TextButton(
                              onPressed: () {},
                              child: const Text('See All', style: TextStyle(color: Colors.greenAccent))),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                GlassPane(
                                  width: 65,
                                  height: 65,
                                  borderRadius: 20,
                                  useBlur: false,
                                  color: cat.color.withOpacity(0.15),
                                  borderColor: cat.color.withOpacity(0.3),
                                  child: Center(child: Icon(cat.icon, color: cat.color, size: 28)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // --- Promo Banner ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.withOpacity(0.8), Colors.teal.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('UP TO 20% OFF', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Book your weekend\nslot now!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.sports_soccer, size: 100, color: Colors.white24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Near You Header ---
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Near You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        GlassPane(padding: const EdgeInsets.all(8), borderRadius: 8, useBlur: false, child: const Icon(Icons.filter_list, size: 20, color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // --- LIVE FIRESTORE LIST (CORRECTED) ---
              StreamBuilder<QuerySnapshot>(
                stream: _filterCity == null
                    ? null
                    : FirebaseFirestore.instance
                    .collection('turfs')
                    .where('city', isEqualTo: _filterCity)
                    .snapshots(),
                builder: (context, snapshot) {
                  // 1. Loading
                  if (_filterCity == null) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.location_off, size: 50, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 10),
                            Text(
                              "No turfs found in $_filterCity",
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final turfId = doc.id;

                        // 1. FIX NAME: Use 'turf_name'
                        final name = data['turf_name'] ?? 'Unknown Turf';

                        // 2. FIX IMAGE: Get first image from 'images' array
                        String imageUrl = 'https://via.placeholder.com/400';
                        if (data['images'] != null && (data['images'] as List).isNotEmpty) {
                          imageUrl = (data['images'] as List).first.toString();
                        }

                        // 3. FIX PRICE: Calculate "Lowest Starting Price"
                        // Your DB has: price_morning, price_afternoon, price_evening, price_night
                        int pMorning = int.tryParse(data['price_morning'].toString()) ?? 0;
                        int pAfter   = int.tryParse(data['price_afternoon'].toString()) ?? 0;
                        int pEve     = int.tryParse(data['price_evening'].toString()) ?? 0;
                        int pNight   = int.tryParse(data['price_night'].toString()) ?? 0;

                        // Collect all valid non-zero prices
                        List<int> allPrices = [pMorning, pAfter, pEve, pNight].where((p) => p > 0).toList();

                        // Get the minimum price to show "From ₹500"
                        int displayPrice = allPrices.isNotEmpty ? allPrices.reduce(min) : 0;

                        final location = data['location'] ?? data['city'] ?? _filterCity;
                        final distance = data['distance'] ?? 'Nearby';

                        double rating = 0.0;
                        var rawRating = data['rating'];
                        if (rawRating is String) {
                          rating = double.tryParse(rawRating) ?? 0.0;
                        } else if (rawRating is num) {
                          rating = rawRating.toDouble();
                        }

                        final isLiked = _favoriteTurfIds.contains(turfId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                          child: GlassPane(
                            padding: EdgeInsets.zero,
                            borderRadius: 24,
                            useBlur: false,
                            color: Colors.white.withOpacity(0.08),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 160,
                                      width: double.infinity,
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900], child: const Icon(Icons.image, color: Colors.white54)),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GlassPane(
                                        padding: const EdgeInsets.all(8),
                                        borderRadius: 50,
                                        useBlur: false,
                                        color: Colors.black.withOpacity(0.4),
                                        onTap: () => _toggleFavorite(turfId),
                                        child: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          size: 20,
                                          color: isLiked ? Colors.redAccent : Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: GlassPane(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        borderRadius: 8,
                                        useBlur: false,
                                        color: Colors.black.withOpacity(0.5),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$rating",
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, overflow: TextOverflow.ellipsis),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                                            ),
                                            child: Text(
                                              // UPDATED PRICE DISPLAY
                                              'From ₹$displayPrice/hr',
                                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '$location • $distance',
                                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => SlotBookingScreen(
                                                  turfId: turfId,
                                                  turfName: name,
                                                  turfImage: imageUrl,
                                                ),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.greenAccent),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            foregroundColor: Colors.greenAccent,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: const Text('View Slots', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),

          // 3. FLOATING NAV BAR
          FloatingNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              if (index == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LikeScreen()));
                return;
              }
              setState(() => _selectedIndex = index);
            },
          ),
        ],
      ),
    );
  }
}