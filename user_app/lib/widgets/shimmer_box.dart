import 'package:flutter/material.dart';

class ShimmerBox extends StatelessWidget {
  final double? height;
  final double? width;
  const ShimmerBox({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? double.infinity,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
