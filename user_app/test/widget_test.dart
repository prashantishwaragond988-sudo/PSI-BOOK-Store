import 'package:flutter_test/flutter_test.dart';
import 'package:our_store/models/book.dart';
import 'package:our_store/models/order_record.dart';

void main() {
  test('Book.fromMap supports website field compatibility', () {
    final book = Book.fromMap('b1', {
      'name': 'Atomic Habits',
      'author': 'James Clear',
      'price': '399',
      'category': 'Self Help',
      'image': 'https://example.com/book.jpg',
    });

    expect(book.id, 'b1');
    expect(book.title, 'Atomic Habits');
    expect(book.author, 'James Clear');
    expect(book.price, 399);
    expect(book.category, 'Self Help');
  });

  test('OrderRecord parses dynamic payload safely', () {
    final order = OrderRecord.fromMap('o1', {
      'total': 899,
      'time': '2026-03-02T10:30:00.000',
      'items': [
        {'book': 'b1', 'qty': 2},
        {'book': 'b2', 'qty': '1'},
      ],
    });

    expect(order.id, 'o1');
    expect(order.total, 899);
    expect(order.items.length, 2);
    expect(order.items.first.bookId, 'b1');
    expect(order.items.first.qty, 2);
    expect(order.items.last.qty, 1);
  });
}
