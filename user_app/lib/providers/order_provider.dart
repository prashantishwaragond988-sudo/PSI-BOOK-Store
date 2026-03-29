import 'package:flutter/foundation.dart';
import '../models/order.dart';

class OrderProvider with ChangeNotifier {
  final List<OrderModel> _orders = [];
  List<OrderModel> get orders => List.unmodifiable(_orders);

  void add(OrderModel order) {
    _orders.insert(0, order);
    notifyListeners();
  }
}
