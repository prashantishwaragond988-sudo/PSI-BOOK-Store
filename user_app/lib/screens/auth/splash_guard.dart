import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/connectivity_provider.dart';
import '../root_shell.dart';
import '../login_screen.dart';
import '../network/no_internet_dialog.dart';

class SplashGuard extends StatefulWidget {
  const SplashGuard({super.key});

  @override
  State<SplashGuard> createState() => _SplashGuardState();
}

class _SplashGuardState extends State<SplashGuard> with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _logoCtrl;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final started = DateTime.now();
    final online = context.read<ConnectivityProvider>().online;
    if (!mounted) return;
    if (!online) {
      await showNoInternetDialog(context);
      if (mounted) _check();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    const minSplash = Duration(milliseconds: 1400);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => user == null ? const LoginScreen() : const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, _) {
              final t = _waveCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(const Color(0xFF0f4ed8), const Color(0xFF0ed3a3), (t + 0.35) % 1)!,
                      Color.lerp(const Color(0xFF0ed3a3), const Color(0xFF0f4ed8), (t + 0.65) % 1)!,
                    ],
                    begin: Alignment(-1 + 2 * t, -1),
                    end: Alignment(1 - 2 * t, 1),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: -80,
            right: -40,
            child: _frostedCircle(180, Colors.white.withOpacity(0.1)),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: _frostedCircle(220, Colors.white.withOpacity(0.07)),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.18),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 56),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "PSI Book Store",
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Curating your next read...",
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 38,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _logoCtrl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Syncing cart, wishlist, and notifications",
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedBuilder(
                        animation: _waveCtrl,
                        builder: (_, __) {
                          return FractionallySizedBox(
                            widthFactor: 0.25 + (_waveCtrl.value * 0.5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _frostedCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
    );
  }
}
