import 'package:flutter/material.dart';

class TurfDetailsScreen extends StatelessWidget {
  final String turfName;
  final String imageUrl;
  final String location;
  final double rating;
  final int pricePerHour;

  const TurfDetailsScreen({
    super.key,
    required this.turfName,
    required this.imageUrl,
    required this.location,
    required this.rating,
    required this.pricePerHour,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Image.network(imageUrl, width: double.infinity, height: 350, fit: BoxFit.cover),

          DraggableScrollableSheet(
            initialChildSize: 0.55,
            maxChildSize: 0.9,
            minChildSize: 0.55,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Text(
                    turfName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.green),
                      const SizedBox(width: 5),
                      Text(location, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      Text("  $rating", style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text("₹$pricePerHour/hr", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  const SizedBox(height: 25),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/slots", arguments: turfName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Check Available Slots", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
