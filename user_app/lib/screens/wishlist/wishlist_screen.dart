import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wishlist_provider.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>().items;
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlist.isEmpty
          ? const Center(child: Text('No items yet'))
          : ListView.builder(
              itemCount: wishlist.length,
              itemBuilder: (_, i) {
                final b = wishlist[i];
                return ListTile(
                  leading: Image.network(b.image, width: 50, fit: BoxFit.cover),
                  title: Text(b.title),
                  subtitle: Text(b.author),
                );
              }),
    );
  }
}
