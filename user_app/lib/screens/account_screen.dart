import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../services/auth_service.dart";
import "../utils/app_router.dart";
import "auth/splash_guard.dart";
import "orders/orders_screen.dart";
import "wishlist/wishlist_screen.dart";
import "addresses/addresses_screen.dart";
import "help_screen.dart";
import "settings_screen.dart";
import "help/ai_chat_screen.dart";

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final bg = theme.colorScheme.background;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Account"),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 16),
          ..._menuCards(context),
          const SizedBox(height: 16),
          _LogoutButton(onTap: () async {
            await AuthService.instance.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SplashGuard()),
              (_) => false,
            );
          }),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final isVerified = user?.emailVerified == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6EFF), Color(0xFF7F53FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? "Guest",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  isVerified ? "Verified user" : "Email not verified",
                  style: TextStyle(
                    color: isVerified ? Colors.greenAccent : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

List<Widget> _menuCards(BuildContext context) {
  final items = [
    ("Orders", Icons.receipt_long, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
    }),
    ("Wishlist", Icons.favorite_border, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
    }),
    ("Addresses", Icons.location_on_outlined, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen()));
    }),
    ("Coupons", Icons.local_offer_outlined, () {
      Navigator.of(context).pushNamed(AppRouter.coupons);
    }),
    ("Help Center", Icons.help_outline, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
    }),
    ("Settings", Icons.settings_outlined, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }),
    ("AI Assistant", Icons.smart_toy_outlined, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
    }),
  ];

  return items
      .map((item) => _AnimatedMenuCard(
            title: item.$1,
            icon: item.$2,
            onTap: item.$3,
          ))
      .toList();
}

class _AnimatedMenuCard extends StatefulWidget {
  const _AnimatedMenuCard(
      {required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_AnimatedMenuCard> createState() => _AnimatedMenuCardState();
}

class _AnimatedMenuCardState extends State<_AnimatedMenuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_pressed ? 0.08 : 0.16),
            blurRadius: _pressed ? 6 : 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(widget.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4B5C), Color(0xFFFF6B6B)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 6),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: const [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
