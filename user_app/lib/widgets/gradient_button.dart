import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  const GradientButton({super.key, required this.text, required this.onTap, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height ?? 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF5B7BFE), Color(0xFF59E2C8)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
