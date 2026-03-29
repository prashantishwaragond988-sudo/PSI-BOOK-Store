import 'package:flutter/foundation.dart';
import '../models/book.dart';

class WishlistProvider with ChangeNotifier {
  final List<Book> _items = [];
  List<Book> get items => List.unmodifiable(_items);

  void toggle(Book b) {
    final idx = _items.indexWhere((x) => x.id == b.id);
    if (idx >= 0) {
      _items.removeAt(idx);
    } else {
      _items.add(b);
    }
    notifyListeners();
  }
}
