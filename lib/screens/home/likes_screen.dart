import 'package:flutter/material.dart';

class LikesScreen extends StatelessWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text("Liked Turfs",
            style: TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}
