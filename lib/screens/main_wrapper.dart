import 'package:flutter/material.dart';
import 'package:bookmyturf/widgets/floating_nav_bar.dart';
import 'package:bookmyturf/screens/home/home_screen.dart';
import 'package:bookmyturf/screens/home/booking_history_screen.dart';
import 'package:bookmyturf/screens/home/likes_screen.dart';
import 'profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    // CalendarScreen(),
    BookingHistoryScreen(),
    LikesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Shows only 1 child at a time (keeps state alive)
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),

          // Floating nav bar always on top
          FloatingNavBar(
            selectedIndex: _currentIndex,
            onItemSelected: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }
}
