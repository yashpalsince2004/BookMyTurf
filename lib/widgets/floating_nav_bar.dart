import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  // This is the visual size of the green indicator, NOT the distance between items
  final double _indicatorWidth = 55;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bounce = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get total width of the floating bar
    final totalWidth = MediaQuery.of(context).size.width * 0.85;

    // 2. Define padding values matching the Container below
    const double horizontalPadding = 18.0;

    // 3. Calculate the actual space available for the 4 icons
    final double availableWidth = totalWidth - (horizontalPadding * 2);

    // 4. Calculate the width of one "slot" for the INDICATOR MATH ONLY
    // We use this to know where to slide the green box.
    final double slotWidth = availableWidth / 4;

    // 5. Calculate Position:
    // (Slot Index * Width) + (Center the indicator in the slot)
    double indicatorPosition = (widget.selectedIndex * slotWidth) +
        (slotWidth - _indicatorWidth) / 2;

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 60,
              width: totalWidth,
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.centerLeft, // Ensure stack aligns left
                children: [
                  // ---------------------------------------------------------
                  // 🌟 Sliding Indicator Behind Selected Icon
                  // ---------------------------------------------------------
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuad,
                    left: indicatorPosition,
                    top: 4,
                    child: Container(
                      width: _indicatorWidth, // Visual width only
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),

                  // ---------------------------------------------------------
                  // 🌟 Navigation Items
                  // ---------------------------------------------------------
                  // Using Expanded inside Row prevents pixel overflow errors
                  Row(
                    children: [
                      _navItem(Icons.home_rounded, 0),
                      _navItem(Icons.calendar_month_rounded, 1),
                      _navItem(Icons.favorite_rounded, 2),
                      _navItem(Icons.person_rounded, 3),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SINGLE NAV ITEM (Uses Expanded to fill space evenly)
  // ---------------------------------------------------------
  Widget _navItem(IconData icon, int index) {
    bool isSelected = widget.selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensures the entire empty space is clickable
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onItemSelected(index);
        },
        child: SizedBox(
          height: 60, // Fill height of container
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) {
              double scale = isSelected ? _bounce.value : 1.0;

              return Center( // Center the icon within its Expanded slot
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    icon,
                    size: 26,
                    color: isSelected ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}