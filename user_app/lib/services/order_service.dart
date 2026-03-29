import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

import "../models/address_record.dart";
import "../models/order_record.dart";
import "cart_service.dart";

class OrderService {
  OrderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CartService? cartService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _cartService = cartService ?? CartService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CartService _cartService;

  String _requireUserEmail() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception("Login required");
    }
    return email;
  }

  Future<String> placeOrderFromCart({
    required AddressRecord address,
    required String paymentMethod,
    String transactionId = "",
  }) async {
    final email = _requireUserEmail();
    final lines = await _cartService.getCartLinesOnce();
    if (lines.isEmpty) {
      throw Exception("Cart empty");
    }

    final items = <Map<String, dynamic>>[];
    var total = 0.0;

    for (final line in lines) {
      if (line.book == null) {
        continue;
      }
      items.add({"book": line.bookId, "qty": line.qty});
      total += line.lineTotal;
    }

    if (items.isEmpty) {
      throw Exception("Cart empty");
    }

    final normalizedMethod = paymentMethod.trim().toUpperCase().isEmpty
        ? "COD"
        : paymentMethod.trim().toUpperCase();
    final paymentStatus = normalizedMethod == "COD"
        ? "pay_on_delivery"
        : (transactionId.trim().isEmpty ? "pending" : "paid");

    final storeIds = lines
        .where((line) => line.book != null)
        .map((line) => line.book!.storeId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final orderStoreId = storeIds.length == 1 ? storeIds.first : "multi-store";

    final orderRef = await _db.collection("orders").add({
      "user": email,
      "store_id": orderStoreId,
      "store_ids": storeIds,
      "total": total.round(),
      "time": DateTime.now().toIso8601String(),
      "items": items,
      "payment_method": normalizedMethod,
      "payment_status": paymentStatus,
      "payment_receiver": "admin",
      "transaction_id": transactionId.trim(),
      "address_id": address.id,
      "address": address.toMap(email),
    });

    await _cartService.clearCartByBookIds(lines.map((e) => e.bookId).toList());
    return orderRef.id;
  }

  Stream<List<OrderRecord>> streamOrders() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value(<OrderRecord>[]);
    }

    return _db
        .collection("orders")
        .where("user", isEqualTo: email)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderRecord.fromMap(doc.id, doc.data()))
              .toList();

          orders.sort((a, b) {
            final at =
                DateTime.tryParse(a.time) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bt =
                DateTime.tryParse(b.time) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
          return orders;
        });
  }
}
