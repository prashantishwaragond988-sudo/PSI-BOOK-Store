import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
    this.opacity = .12,
    this.borderOpacity = .25,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  final double borderOpacity;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
