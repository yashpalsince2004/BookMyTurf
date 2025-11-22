import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';


class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  _CityPickerScreenState createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final List<String> popularCities = [
    "Mumbai",
    "Delhi NCR",
    "Bengaluru",
    "Hyderabad",
    "Chandigarh",
    "Ahmedabad",
    "Pune",
    "Chennai",
    "Kolkata",
    "Kochi",
  ];

  bool isDetecting = false;
  String? detectedCity;

  Future<void> detectLocation() async {
    if (isDetecting) return; // Prevent multiple taps

    setState(() => isDetecting = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable location services")),
      );
      setState(() => isDetecting = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please allow location to continue.")),
      );
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Location blocked. Open Settings."),
          action: SnackBarAction(
            label: "Settings",
            onPressed: () async => Geolocator.openAppSettings(),
          ),
        ),
      );
      setState(() => isDetecting = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      detectedCity = placemarks.first.locality ?? placemarks.first.administrativeArea;

      Navigator.pop(context, detectedCity);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error detecting location: $e")),
      );
    }

    setState(() => isDetecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Select City",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search for your city",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Auto Detect Location Button ---- UPDATED
            GestureDetector(
              onTap: isDetecting ? null : detectLocation,
              child: Row(
                children: [
                  isDetecting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.red,
                    ),
                  )
                      : const Icon(Icons.my_location, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    isDetecting ? "Detecting..." : "Auto Detect My Location",
                    style: TextStyle(
                      fontSize: 15,
                      color: isDetecting ? Colors.grey : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              "POPULAR CITIES",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: popularCities.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final city = popularCities[index];

                  return GestureDetector(
                    onTap: () => Navigator.pop(context, city),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city, size: 40, color: Colors.black87),
                        const SizedBox(height: 6),
                        Text(
                          city,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
    );
  }
}
