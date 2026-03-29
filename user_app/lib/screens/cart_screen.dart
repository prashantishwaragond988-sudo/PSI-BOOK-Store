import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../models/product_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.background;
    return Container(
      color: bg,
      child: SafeArea(
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.items.isEmpty) {
              return const Center(
                child: Text(
                  "Your cart is empty",
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final entry = cart.items[i];
                      return _CartRow(entry: entry, theme: theme);
                    },
                  ),
                ),
                _TotalBar(total: cart.totalPrice, theme: theme),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.entry, required this.theme});
  final CartEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final product = entry.product;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.image,
                width: 70,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade300),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Text("Rs ${product.price.toStringAsFixed(0)}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      context.read<CartProvider>().decrement(product),
                ),
                Text(entry.quantity.toString(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: isDark ? Colors.white : Colors.black)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () =>
                      context.read<CartProvider>().increment(product),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, required this.theme});
  final double total;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.4) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 4),
                Text("Rs ${total.toStringAsFixed(0)}",
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("Checkout"),
          )
        ],
      ),
    );
  }
}
