class OrderItem {
  const OrderItem({required this.bookId, required this.qty});

  final String bookId;
  final int qty;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawQty = map["qty"];
    final qty = rawQty is num ? rawQty.toInt() : int.tryParse("$rawQty") ?? 0;
    return OrderItem(bookId: (map["book"] ?? "").toString(), qty: qty);
  }
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.total,
    required this.time,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.transactionId,
    required this.addressText,
  });

  final String id;
  final double total;
  final String time;
  final List<OrderItem> items;
  final String paymentMethod;
  final String paymentStatus;
  final String transactionId;
  final String addressText;

  factory OrderRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawTotal = map["total"];
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse("$rawTotal") ?? 0;

    final rawItems = map["items"];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
              .toList()
        : <OrderItem>[];

    final addressMap = map["address"];
    String addressText = "";
    if (addressMap is Map) {
      final row = Map<String, dynamic>.from(addressMap);
      final parts = <String>[
        (row["fullname"] ?? "").toString(),
        (row["street"] ?? "").toString(),
        (row["landmark"] ?? "").toString(),
        (row["city"] ?? "").toString(),
        (row["pincode"] ?? "").toString(),
        (row["mobile"] ?? "").toString(),
      ].where((part) => part.trim().isNotEmpty);
      addressText = parts.join(", ");
    }

    return OrderRecord(
      id: id,
      total: total,
      time: (map["time"] ?? "").toString(),
      items: items,
      paymentMethod: (map["payment_method"] ?? "COD").toString(),
      paymentStatus: (map["payment_status"] ?? "").toString(),
      transactionId: (map["transaction_id"] ?? "").toString(),
      addressText: addressText,
    );
  }
}
