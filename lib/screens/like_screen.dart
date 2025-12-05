import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bookmyturf/widgets/glass_pane.dart';
import 'package:bookmyturf/models/turf_models.dart';
import 'package:bookmyturf/screens/booking/slot_booking_screen.dart';

class LikeScreen extends StatefulWidget {
  const LikeScreen({super.key});

  @override
  State<LikeScreen> createState() => _LikeScreenState();
}

class _LikeScreenState extends State<LikeScreen> {
  List<String> _favoriteIds = [];
  bool _isLoadingIds = true; // Renamed for clarity

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ---------------------------------------------------
  // 1. LOAD FAVORITE TURF IDs
  // ---------------------------------------------------
  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingIds = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('favTurf')) {
        setState(() {
          _favoriteIds = List<String>.from(doc['favTurf']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching User Favorites: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingIds = false);
      }
    }
  }

  // ---------------------------------------------------
  // 2. FETCH TURF DETAILS (ROBUST VERSION)
  // ---------------------------------------------------
  Future<TurfVenue?> _fetchTurfDetails(String turfId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(turfId)
          .get();

      if (!doc.exists) {
        print("❌ DEBUG: Turf ID '$turfId' does NOT exist in the 'turfs' collection.");
        return null;
      }
      print("✅ DEBUG: Found Turf '$turfId'. Data: ${doc.data()}");

      final data = doc.data()!;

      // Safe Image Parsing
      String displayImage = "https://via.placeholder.com/500";
      if (data['images'] != null &&
          data['images'] is List &&
          (data['images'] as List).isNotEmpty) {
        displayImage = data['images'][0].toString();
      }

      // Safe Price Parsing
      int price = 500;
      if (data['price'] != null) {
        price = int.tryParse(data['price'].toString()) ?? 500;
      }

      return TurfVenue(
        id: turfId,
        name: data['turfName'] ?? "Unknown Turf",
        location: data['location'] ?? "Unknown Location",
        rating: double.tryParse(data['rating'].toString()) ?? 4.5,
        pricePerHour: price,
        imageUrl: displayImage,
        distance: data['distance'] ?? "1 km",
      );
    } catch (e) {
      print("🔥 DEBUG: Error parsing Turf '$turfId': $e");
      return null;
    }
  }

  // ---------------------------------------------------
  // 3. UNLIKE FUNCTION
  // ---------------------------------------------------
  Future<void> _unlike(String turfId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Remove from UI immediately for snappy feel
    setState(() {
      _favoriteIds.remove(turfId);
    });

    // Remove from Backend
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'favTurf': FieldValue.arrayRemove([turfId])
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black, // Solid black background behind glass
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Liked Turfs",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),

      // ---------------------------------------------------
      // BODY
      // ---------------------------------------------------
      body: _isLoadingIds
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _favoriteIds.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _favoriteIds.length,
        itemBuilder: (context, index) {
          final turfId = _favoriteIds[index];

          return FutureBuilder<TurfVenue?>(
            future: _fetchTurfDetails(turfId),
            builder: (context, snapshot) {
              // 1. Loading State
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingSkeleton();
              }

              // 2. Error or Null State (Turf deleted from DB?)
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return const SizedBox.shrink(); // Hide invalid items gracefully
              }

              // 3. Success State
              final turf = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TurfCard(
                  venue: turf,
                  onUnlike: () => _unlike(turf.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            "No liked turfs yet",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 250,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////////
/// TURF CARD WIDGET
//////////////////////////////////////////////////////////////////

class _TurfCard extends StatelessWidget {
  final TurfVenue venue;
  final VoidCallback onUnlike;

  const _TurfCard({
    required this.venue,
    required this.onUnlike,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: EdgeInsets.zero,
      borderRadius: 22,
      useBlur: false,
      color: Colors.white.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // * TURF IMAGE *
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.network(
                  venue.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      color: Colors.grey[900],
                      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54)),
                    );
                  },
                ),
              ),
              // Heart Icon overlaid on image (Optional, but looks nice)
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                    onPressed: onUnlike,
                  ),
                ),
              ),
            ],
          ),

          // * DETAILS *
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue.location,
                        style: const TextStyle(color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "₹${venue.pricePerHour}/hr",
                      style: const TextStyle(
                          color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SlotBookingScreen(
                            turfId: venue.id,
                            turfName: venue.name,
                            turfImage: venue.imageUrl,
                            // pricePerHour: venue.pricePerHour, // Added this safely
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      foregroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "View Slots",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}