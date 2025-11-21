import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text("Calendar Screen",
            style: TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}
