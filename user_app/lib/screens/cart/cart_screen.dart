import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/gradient_button.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = cart.items[i];
                return ListTile(
                  leading: CachedNetworkImage(
                    imageUrl: item.product.image,
                    width: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 32),
                  ),
                  title: Text(item.product.title),
                  subtitle: Text('₹${item.product.price.toStringAsFixed(0)}  x${item.quantity}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => cart.remove(item.product),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                text: 'Checkout · ₹${cart.totalPrice.toStringAsFixed(0)}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
              ),
            ),
    );
  }
}
