import "book.dart";

class CartLine {
  const CartLine({required this.bookId, required this.qty, required this.book});

  final String bookId;
  final int qty;
  final Book? book;

  double get lineTotal => (book?.price ?? 0) * qty;
}
