import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/home_provider.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/add_to_cart_button.dart';
import '../../animations/popup_success.dart';
import '../../providers/cart_provider.dart';
import '../product/product_detail_screen.dart';
import '../../widgets/network_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const NetworkBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(),
                    const SizedBox(height: 12),
                    _BannerCarousel(images: home.banners),
                    const SizedBox(height: 16),
                    _CategoryRow(categories: home.categories),
                    const SizedBox(height: 12),
                    Text('Top Selling', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (home.loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _BookGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // bottom nav rendered by RootShell
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search books, authors...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white.withOpacity(.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<String> images;
  const _BannerCarousel({required this.images});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: .9);
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(widget.images[i], fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.images.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _index == i ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _index == i ? Theme.of(context).colorScheme.primary : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        )
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<String> categories;
  const _CategoryRow({required this.categories});
  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = home.selectedCategory == categories[i];
          return Column(
            children: [
              GestureDetector(
                onTap: () => home.selectCategory(categories[i]),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.menu_book_rounded,
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(height: 6),
              Text(categories[i], style: const TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final books = context.watch<HomeProvider>().filtered;
    if (books.isEmpty) {
      return const Text('No books found.');
    }
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final b = books[i];
        final safeImg = b.image.startsWith('http') ? b.image : 'https://via.placeholder.com/300x420';
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductDetailScreen(book: b)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: safeImg,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(b.author, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      RatingStars(rating: b.rating),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('₹${b.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          AddToCartButton(onTap: () {
                            context.read<CartProvider>().add(b);
                            showSuccess(context, 'Item added to cart');
                          }),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
