import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = const [
      Icons.home_filled,
      Icons.category_rounded,
      Icons.shopping_cart_rounded,
      Icons.person_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white.withOpacity(0.08),
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            currentIndex: currentIndex,
            onTap: onTap,
            items: List.generate(
              items.length,
              (i) => BottomNavigationBarItem(
                icon: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: currentIndex == i ? 1.2 : 1.0,
                  child: Icon(items[i]),
                ),
                label: '',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
