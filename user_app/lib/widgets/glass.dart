import 'dart:ui';

import 'package:flutter/material.dart';

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.opacity = 0.15,
    this.borderOpacity = 0.2,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets? padding;
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
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
