import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bookmyturf/widgets/floating_nav_bar.dart'; // Ensure this path is correct
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // IMPORTED
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async'; // For StreamSubscription

import '../city_picker_screen.dart'; // Ensure path is correct
import '../slot_booking_screen.dart'; // Ensure path is correct

// ---------------------------------------------
// MODELS
// ---------------------------------------------
class SportCategory {
  final String name;
  final IconData icon;
  final Color color;

  SportCategory(this.name, this.icon, this.color);
}

class TurfVenue {
  final String id;
  final String name;
  final String location;
  final double rating;
  final int pricePerHour;
  final String imageUrl;
  final String distance;

  TurfVenue({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.pricePerHour,
    required this.imageUrl,
    required this.distance,
  });
}

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
  int _selectedIndex = 0;

  // --- FAVORITES LOGIC VARIABLES ---
  List<String> _favoriteTurfIds = [];
  StreamSubscription<DocumentSnapshot>? _favSubscription;

  @override
  void initState() {
    super.initState();
    _askLocationPermission();
    _fetchLocation();
    _listenToFavorites(); // Start listening to Firestore
    _ensureUserDocumentExists(); // <--- ADD THIS CALL
  }
  // --- NEW ROBUST FUNCTION ---
  Future<void> _ensureUserDocumentExists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print("👤 Checking database for User ID: ${user.uid}");

        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          print("📝 Document missing. Creating new user document...");

          await userDocRef.set({
            'uid': user.uid,
            'email': user.email ?? 'No Email',
            'phone': user.phoneNumber ?? 'No Phone',
            'name': user.displayName ?? 'New Player',
            'createdAt': FieldValue.serverTimestamp(),
            'favTurf': [], // Empty favorites list
          }, SetOptions(merge: true));

          print("✅ SUCCESS: User document created in Firestore!");
        } else {
          print("ℹ️ User document already exists. No action needed.");
        }
      } else {
        print("❌ ERROR: No user is currently logged in.");
      }
    } catch (e) {
      print("🔥 FIRESTORE ERROR: $e");
    }
  }
// ... rest of your code (dispose, toggleFavorite, etc.)
  @override
  void dispose() {
    _favSubscription?.cancel(); // Clean up listener
    super.dispose();
  }

  // 1. LISTEN TO FIRESTORE CHANGES LIVE
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

  // 2. TOGGLE LIKE FUNCTION
  Future<void> _toggleFavorite(String turfId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to save favorites!")),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Haptic feedback for better UX
    HapticFeedback.mediumImpact();

    if (_favoriteTurfIds.contains(turfId)) {
      // Remove from favorites
      await userRef.update({
        'favTurf': FieldValue.arrayRemove([turfId])
      });
    } else {
      // Add to favorites (set with merge ensures doc exists)
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
          currentCity = "${place.locality}, ${place.administrativeArea}";
        });
      }
    }
  }

  final List<SportCategory> _categories = [
    SportCategory('Football', Icons.sports_soccer, Colors.greenAccent),
    SportCategory('Cricket', Icons.sports_cricket, Colors.lightBlueAccent),
    SportCategory('Badminton', Icons.sports_tennis, Colors.orangeAccent),
    SportCategory('Tennis', Icons.sports_tennis_outlined, Colors.redAccent),
    SportCategory('Basketball', Icons.sports_basketball, Colors.deepOrangeAccent),
  ];

  final List<TurfVenue> _nearbyTurfs = [
    TurfVenue(
      id: '1',
      name: 'Galaxy Sports Arena',
      location: 'Kalyan West, Mumbai',
      rating: 4.8,
      pricePerHour: 1200,
      imageUrl: 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=500&q=60',
      distance: '1.2 km',
    ),
    TurfVenue(
      id: '2',
      name: 'Urban Kick Turf',
      location: 'Thane, Mumbai',
      rating: 4.5,
      pricePerHour: 900,
      imageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?auto=format&fit=crop&w=500&q=60',
      distance: '3.5 km',
    ),
    TurfVenue(
      id: '3',
      name: 'Smash Badminton Court',
      location: 'Dombivli East',
      rating: 4.9,
      pricePerHour: 600,
      imageUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=500&q=60',
      distance: '5.0 km',
    ),
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
      backgroundColor: Colors.black, // Fallback color
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
            // PERFORMANCE: Pre-load content 800px ahead to prevent jank
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
                // Keep blur here, it's static
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
                          setState(() => currentCity = selectedCity);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Keep items packed
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.greenAccent),
                          const SizedBox(width: 4),
                          // Flexible prevents overflow
                          Flexible(
                            child: Text(
                              currentCity ?? "Select Location",
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
                        } else if (user?.phoneNumber != null) {
                          final raw = user!.phoneNumber!;
                          if (raw.length > 4) {
                            name = "${raw.substring(0, 4)}•••${raw.substring(raw.length - 2)}";
                          } else {
                            name = raw;
                          }
                        }
                        return Text(
                          "Hello, $name 👋",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  Stack(
                    children: [
                      _GlassPane(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 12,
                        useBlur: true, // Keep blur for top elements
                        onTap: () {},
                        child: const Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
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
                    child: _GlassPane(
                      padding: EdgeInsets.zero,
                      borderRadius: 16,
                      useBlur: true, // Keep blur
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search "Cricket Turf"',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                          const Text(
                            'Categories',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('See All', style: TextStyle(color: Colors.greenAccent)),
                          ),
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
                                _GlassPane(
                                  width: 65,
                                  height: 65,
                                  borderRadius: 20,
                                  // PERFORMANCE: Disable blur for lists
                                  useBlur: false,
                                  color: cat.color.withOpacity(0.15),
                                  borderColor: cat.color.withOpacity(0.3),
                                  child: Center(
                                    child: Icon(cat.icon, color: cat.color, size: 28),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                      // Keep blur for this one large item, it's usually okay
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.8),
                              Colors.teal.withOpacity(0.6),
                            ],
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
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'UP TO 20% OFF',
                                      style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Book your weekend\nslot now!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.green[800],
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Transform.rotate(
                              angle: -0.2,
                              child: Icon(
                                Icons.sports_soccer,
                                size: 110,
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
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
                        const Text(
                          'Near You',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        _GlassPane(
                          padding: const EdgeInsets.all(8),
                          borderRadius: 8,
                          useBlur: false, // Performance
                          child: const Icon(Icons.filter_list, size: 20, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // --- Venue List ---
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final venue = _nearbyTurfs[index];

                    // CHECK IF LIKED
                    final isLiked = _favoriteTurfIds.contains(venue.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                      child: _GlassPane(
                        padding: EdgeInsets.zero,
                        borderRadius: 24,
                        // PERFORMANCE: IMPORTANT - Disable blur for big list items
                        useBlur: false,
                        color: Colors.white.withOpacity(0.08),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image Area
                            Stack(
                              children: [
                                SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                    child: Image.network(
                                      venue.imageUrl,
                                      fit: BoxFit.cover,
                                      // PERFORMANCE: Cache size optimization
                                      cacheHeight: 400,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(Icons.image_not_supported, color: Colors.white.withOpacity(0.3), size: 40),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // --- WORKING LIKE BUTTON ---
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: _GlassPane(
                                    padding: const EdgeInsets.all(8),
                                    borderRadius: 50,
                                    useBlur: false,
                                    color: Colors.black.withOpacity(0.4),
                                    onTap: () {
                                      _toggleFavorite(venue.id);
                                    },
                                    child: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      size: 20,
                                      color: isLiked ? Colors.redAccent : Colors.white,
                                    ),
                                  ),
                                ),
                                // Rating Badge
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _GlassPane(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    borderRadius: 8,
                                    useBlur: false,
                                    color: Colors.black.withOpacity(0.5),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          venue.rating.toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Info Area
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
                                          venue.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                                          '₹${venue.pricePerHour}/hr',
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
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
                                          '${venue.location} • ${venue.distance}',
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
                                              turfId: venue.id,
                                              turfName: venue.name,
                                              turfImage: venue.imageUrl,
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
                  childCount: _nearbyTurfs.length,
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),

          // 3. FLOATING NAV BAR
          FloatingNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// REUSABLE "LIQUID GLASS" WIDGET (OPTIMIZED)
// ---------------------------------------------------------------------
class _GlassPane extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  // NEW: Toggle blur for performance
  final bool useBlur;

  const _GlassPane({
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.width,
    this.height,
    this.onTap,
    this.color,
    this.borderColor,
    this.useBlur = true, // Default to true, set false for list items
  });

  @override
  Widget build(BuildContext context) {
    // 1. Base Container configuration
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.12), // Default frosted color
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );

    // 2. Performance Check: If useBlur is false, return just the container
    //    (The semi-transparent color simulates glass without the GPU cost)
    if (!useBlur) {
      return content;
    }

    // 3. If useBlur is true, wrap in BackdropFilter (Heavy)
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      ),
    );
  }
}