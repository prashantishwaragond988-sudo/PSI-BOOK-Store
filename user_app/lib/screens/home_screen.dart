import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

import '../models/book_model.dart';
import '../models/book.dart';
import '../services/firebase_service.dart';
import '../widgets/banner_slider.dart';
import '../widgets/book_card.dart';
import '../widgets/category_chip.dart';
import 'book_detail_screen.dart';
import '../providers/cart_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _categories = const ["All", "Fiction", "Self Help", "Education", "Business", "Comics"];
  String _selectedCat = "All";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.brightness == Brightness.dark
        ? const Color(0xFF0F172A)
        : Colors.white;
    return Container(
      color: bg,
      child: Column(
        children: [
          _banner(),
          _chips(),
          Expanded(child: _gridSection()),
        ],
      ),
    );
  }

  Widget _banner() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: BannerSlider(
          items: List.generate(
            3,
            (i) => Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=1200&q=80',
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(.6), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  bottom: 16,
                  child: Text(
                    'Discover great reads',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _chips() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => CategoryChip(
              label: _categories[i],
              icon: _iconFor(_categories[i]),
              selected: _categories[i] == _selectedCat,
              onTap: () => setState(() => _selectedCat = _categories[i]),
            ),
          ),
        ),
      );

  Widget _gridSection() {
    return StreamBuilder<List<BookModel>>(
      stream: FirebaseService.instance.streamBooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _shimmerGrid();
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(
              child: Text('No books found', style: TextStyle(color: Colors.white)));
        }
        var books = snap.data!;
        if (_selectedCat != 'All') {
          books = books
              .where((b) => b.category.toLowerCase() == _selectedCat.toLowerCase())
              .toList();
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemBuilder: (_, i) {
            final book = books[i];
            return BookCard(
              book: book,
              heroTag: book.image,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                );
              },
              onAdd: () => _addToCart(book),
            );
          },
        );
      },
    );
  }

  Future<void> _addToCart(BookModel book) async {
    final cart = context.read<CartProvider>();
    try {
      await cart.add(_toBook(book));
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _SuccessDialog(message: 'Added to cart'),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _SuccessDialog(
          message: 'Failed to add: $e',
          isError: true,
        ),
      );
    }
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

  Widget _shimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.white10,
        highlightColor: Colors.white24,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower == 'all') return Icons.auto_awesome;
    if (lower.contains('fic')) return Icons.menu_book_rounded;
    if (lower.contains('self')) return Icons.self_improvement;
    if (lower.contains('edu')) return Icons.school;
    if (lower.contains('bus')) return Icons.business_center;
    return Icons.theater_comedy;
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
      title: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green),
          const SizedBox(width: 8),
          Text(isError ? 'Oops' : 'Success'),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
