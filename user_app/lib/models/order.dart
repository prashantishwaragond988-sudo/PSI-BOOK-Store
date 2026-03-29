import 'cart_item.dart';
import 'address.dart';

class OrderModel {
  final String id;
  final List<CartItem> items;
  final Address address;
  final String status;
  final double totalPrice;
  final String paymentMethod;

  OrderModel({
    this.id = '',
    required this.items,
    required this.address,
    required this.status,
    required this.totalPrice,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() => {
        'items': items.map((e) => e.toMap()).toList(),
        'address': address.toMap(),
        'status': status,
        'total_price': totalPrice,
        'payment_method': paymentMethod,
      };
}
