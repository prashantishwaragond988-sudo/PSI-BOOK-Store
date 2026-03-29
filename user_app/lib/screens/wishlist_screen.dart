import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../models/book.dart";
import "../services/cart_service.dart";
import "../services/wishlist_service.dart";
import "../utils/interaction_fx.dart";
import "../widgets/animated_book_image.dart";

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _wishlistService = WishlistService();
  final _cartService = CartService();
  final _money = NumberFormat.currency(locale: "en_IN", symbol: "Rs ");

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _remove(String bookId) async {
    unawaited(playTapFx());
    try {
      await _wishlistService.toggle(bookId);
    } catch (error) {
      _toast("Unable to update wishlist.");
    }
  }

  Future<void> _addToCart(String bookId) async {
    unawaited(playTapFx());
    try {
      await _cartService.addBook(bookId);
      _toast("Added to cart");
    } catch (error) {
      _toast("Unable to add to cart.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Book>>(
      stream: _wishlistService.streamWishlistBooks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Unable to load wishlist."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final books = snapshot.data ?? <Book>[];
        if (books.isEmpty) {
          return const Center(child: Text("Wishlist is empty."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: books.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final book = books[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedBookImage(
                        rawImage: book.image,
                        width: 70,
                        height: 90,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B1F44),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.author.isEmpty
                                ? "Unknown author"
                                : book.author,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _money.format(book.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _remove(book.id),
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.red,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _addToCart(book.id),
                          child: const Text("Add"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
