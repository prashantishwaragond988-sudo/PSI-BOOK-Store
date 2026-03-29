import 'book.dart';

class CartItem {
  final Book book;
  int qty;
  CartItem({required this.book, this.qty = 1});

  Map<String, dynamic> toMap() => {
        'book_id': book.id,
        'qty': qty,
        'price': book.price,
      };
}
