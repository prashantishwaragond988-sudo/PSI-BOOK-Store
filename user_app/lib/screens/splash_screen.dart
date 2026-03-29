import "dart:async";
import "dart:ui";

import "package:flutter/material.dart";

import "auth/splash_guard.dart";
import "../widgets/glass.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..forward();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashGuard()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f4ed8), Color(0xFF0ed3a3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -60,
              child: _glowCircle(220, Colors.white.withOpacity(0.12)),
            ),
            Positioned(
              bottom: -100,
              left: -40,
              child: _glowCircle(260, Colors.white.withOpacity(0.1)),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _controller, curve: Curves.easeOutBack),
                child: Glass(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 86,
                        height: 86,
                        child: Glass(
                          radius: 28,
                          opacity: 0.2,
                          shadow: false,
                          child: Icon(Icons.menu_book_rounded,
                              size: 44, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        "PSI Book Store",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 60,
              spreadRadius: 10,
            )
          ],
        ),
      );
}
