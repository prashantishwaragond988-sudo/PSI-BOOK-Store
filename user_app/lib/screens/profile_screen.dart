import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: const SafeArea(
        child: Center(
          child: Text(
            "Profile coming soon",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
