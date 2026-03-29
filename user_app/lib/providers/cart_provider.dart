import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../models/book.dart";
import "../models/product_model.dart";
import "../services/cart_service.dart";

class CartEntry {
  CartEntry({required this.product, required this.quantity});
  final ProductModel product;
  int quantity;
}

class CartProvider extends ChangeNotifier {
  CartProvider() {
    _subscription = _cartService.streamCartLines().listen((lines) {
      _items
        ..clear()
        ..addEntries(
          lines.where((line) => line.book != null).map((line) {
            final book = line.book as Book;
            return MapEntry(
              book.id,
              CartEntry(
                product: _productFromBook(book),
                quantity: line.qty,
              ),
            );
          }),
        );
      notifyListeners();
    });
  }

  final CartService _cartService = CartService();
  final Map<String, CartEntry> _items = {};
  late final StreamSubscription _subscription;

  List<CartEntry> get items => _items.values.toList();

  int get totalItems =>
      _items.values.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.values.fold<double>(
        0,
        (sum, item) => sum + (item.product.price * item.quantity),
      );

  ProductModel _productFromBook(Book book) {
    return ProductModel(
      id: book.id,
      title: book.title,
      price: book.price,
      description: book.description,
      category: book.category,
      image: book.image,
      rating: 4.5,
      ratingCount: 0,
      author: book.author,
    );
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      await _cartService.addBook(product.id);
    } catch (e) {
      debugPrint("Cart add error: $e");
    }
  }

  Future<void> remove(ProductModel product) async {
    try {
      await _cartService.removeBook(product.id);
    } catch (e) {
      debugPrint("Cart remove error: $e");
    }
  }

  Future<void> increment(ProductModel product) async {
    try {
      await _cartService.addBook(product.id);
    } catch (e) {
      debugPrint("Cart increment error: $e");
    }
  }

  Future<void> add(Book book, {int qty = 1}) async {
    for (int i = 0; i < qty; i++) {
      await addProduct(_productFromBook(book));
    }
  }

  Future<void> decrement(ProductModel product) async {
    try {
      await _cartService.decreaseBook(product.id);
    } catch (e) {
      debugPrint("Cart decrement error: $e");
    }
  }

  Future<void> clear() async {
    final ids = _items.keys.toList();
    try {
      await _cartService.clearCartByBookIds(ids);
    } catch (e) {
      debugPrint("Cart clear error: $e");
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
