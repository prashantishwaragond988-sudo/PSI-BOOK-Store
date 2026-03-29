
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/book_model.dart';
import '../models/book.dart';
import '../providers/cart_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/book_card.dart';
import '../widgets/search_bar.dart';
import 'book_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.background;
    return Container(
      color: bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: GlassSearchBar(onChanged: (v) => setState(() => _query = v)),
          ),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  Widget _grid() {
    return StreamBuilder<List<BookModel>>(
      stream: FirebaseService.instance.streamBooks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _shimmerGrid();
        }
        var books = snap.data ?? [];
        if (_query.isNotEmpty) {
          books = books
              .where((b) =>
                  b.title.toLowerCase().contains(_query.toLowerCase()) ||
                  b.author.toLowerCase().contains(_query.toLowerCase()))
              .toList();
        }
        if (books.isEmpty) {
          return const Center(
              child: Text("No books found", style: TextStyle(color: Colors.white70)));
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
              ),
              onAdd: () => _add(book),
            );
          },
        );
      },
    );
  }

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

  Future<void> _add(BookModel m) async {
    final cart = context.read<CartProvider>();
    await cart.add(_toBook(m));
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.green.shade50,
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Added to cart'),
          ],
        ),
        content: Text(m.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
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
