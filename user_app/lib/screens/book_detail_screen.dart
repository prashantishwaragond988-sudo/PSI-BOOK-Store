import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book_model.dart';
import '../models/book.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.book});

  final BookModel book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  double _userRating = 4.0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final theme = Theme.of(context);
    final bg = theme.colorScheme.background;
    final onBg = theme.colorScheme.onBackground;
    final faint = onBg.withOpacity(0.6);
    final gradient =
        const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)]);
    final combined = (book.rating + _userRating) / 2;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(book.title, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: book.image,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: book.image,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 320, color: Colors.white10),
                  errorWidget: (_, __, ___) => Container(
                      height: 320,
                      color: Colors.white12,
                      child:
                          const Icon(Icons.broken_image, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: onBg)),
                  const SizedBox(height: 6),
                  Text(book.author, style: TextStyle(color: faint, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade400),
                      const SizedBox(width: 6),
                      Text(book.rating.toStringAsFixed(1),
                          style: TextStyle(color: onBg)),
                      const SizedBox(width: 8),
                      Text("(website)", style: TextStyle(color: faint)),
                      const Spacer(),
                      Text("Rs ${book.price.toStringAsFixed(0)}",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: onBg)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text("Your rating:",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _userRating,
                          min: 1,
                          max: 5,
                          divisions: 8,
                          label: _userRating.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _userRating = v),
                        ),
                      ),
                      Text(_userRating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text("Combined rating:",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(combined.toStringAsFixed(1),
                          style: TextStyle(
                              color: onBg, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(_submitting ? "Submitting..." : "Submit rating"),
                      onPressed: _submitting ? null : () => _submitRating(book),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Description",
                    style: TextStyle(
                        color: onBg, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (book.description.isNotEmpty
                        ? book.description
                        : "Dive into the world of ${book.title}. A captivating read by ${book.author}."),
                    style: TextStyle(color: faint, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _GradientButton(
                          gradient: gradient,
                          label: "Add to Cart",
                          onTap: () => _addToCart(book),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GradientButton(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A00), Color(0xFFFF3D71)]),
                          label: "Buy Now",
                          onTap: () => _buyNow(book),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(BookModel book) async {
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('book_ratings').add({
        'bookId': book.id,
        'value': _userRating,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Thanks!'),
          content: Text('Your rating was submitted and will help others.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('Could not submit rating: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addToCart(BookModel book) async {
    final cart = context.read<CartProvider>();
    await cart.add(_toBook(book));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Added to cart'),
        content: Text('This book was added to your cart.'),
      ),
    );
  }

  Future<void> _buyNow(BookModel book) async {
    final cart = context.read<CartProvider>();
    await cart.add(_toBook(book));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  Book _toBook(BookModel m) => Book(
        id: m.id,
        title: m.title,
        author: m.author,
        image: m.image,
        images: [m.image],
        price: m.price,
        rating: m.rating,
        category: m.category,
        description: m.description,
      );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.gradient,
    required this.label,
    required this.onTap,
  });

  final LinearGradient gradient;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
