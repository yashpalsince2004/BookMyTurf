import 'package:flutter/material.dart'; // Required for IconData and Color
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