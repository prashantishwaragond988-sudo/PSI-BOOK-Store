import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/qty_selector.dart';
import '../../providers/cart_provider.dart';
import '../../animations/popup_success.dart';
import '../checkout/checkout_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Book book;
  const ProductDetailScreen({super.key, required this.book});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            flexibleSpace: FlexibleSpaceBar(
              background: PageView(
                children: b.images
                    .map((img) => CachedNetworkImage(
                          imageUrl: img.startsWith('http') ? img : 'https://via.placeholder.com/600x800',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                        ))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: Theme.of(context).textTheme.headlineSmall),
                  Text('by ${b.author}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  RatingStars(rating: b.rating),
                  const SizedBox(height: 8),
                  Text('₹${b.price.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  QuantitySelector(value: qty, onChanged: (v) => setState(() => qty = v)),
                  const SizedBox(height: 16),
                  GradientButton(text: 'Add to Cart', onTap: () {
                    context.read<CartProvider>().add(b, qty: qty);
                    showSuccess(context, 'Item added to cart');
                  }),
                  const SizedBox(height: 10),
                  GradientButton(text: 'Buy Now', onTap: () async {
                    final cart = context.read<CartProvider>();
                    await cart.add(b, qty: qty);
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CheckoutScreen(),
                    ));
                  }),
                  const SizedBox(height: 16),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(b.description),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
