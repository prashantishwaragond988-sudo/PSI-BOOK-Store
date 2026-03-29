import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/book_model.dart';
import 'glass_container.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onAdd,
    this.heroTag,
  });

  final BookModel book;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.white70 : Colors.black54;
    final gradient = const LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
    );

    final card = GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: book.image,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: isDark ? Colors.white10 : Colors.black12),
              errorWidget: (_, __, ___) => Icon(Icons.broken_image,
                  color: isDark ? Colors.white70 : Colors.black38),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.w700),
                ),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade400, size: 16),
                    const SizedBox(width: 4),
                    Text("${book.rating}",
                        style: TextStyle(color: textColor)),
                    const Spacer(),
                    Text(
                      "Rs ${book.price.toStringAsFixed(0)}",
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const Spacer(),
                _GradientButton(
                  gradient: gradient,
                  onTap: onAdd,
                  child: const Text("Add to Cart"),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final wrapped = heroTag == null ? card : Hero(tag: heroTag!, child: card);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: wrapped);
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.child,
    required this.onTap,
    required this.gradient,
  });

  final Widget child;
  final VoidCallback onTap;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: DefaultTextStyle(
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
