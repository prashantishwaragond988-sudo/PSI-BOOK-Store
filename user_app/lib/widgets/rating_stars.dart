import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  const RatingStars({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = rating > i && rating < i + 1;
        return Icon(
          filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }
}
