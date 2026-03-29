import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../models/book.dart";
import "../models/order_record.dart";
import "../services/book_service.dart";
import "../services/order_service.dart";
import "../utils/app_router.dart";

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();
    final money = NumberFormat.currency(locale: "en_IN", symbol: "Rs ");

    return StreamBuilder<List<OrderRecord>>(
      stream: orderService.streamOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? <OrderRecord>[];
        if (orders.isEmpty) {
          return const Center(child: Text("No orders yet."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final dt = DateTime.tryParse(order.time);
            final dateText = dt == null
                ? order.time
                : DateFormat("dd MMM yyyy, hh:mm a").format(dt.toLocal());

            final firstBookId =
                order.items.isNotEmpty ? order.items.first.bookId : "";

            return FutureBuilder<Book?>(
              future: firstBookId.isEmpty
                  ? Future.value(null)
                  : BookService().getBookById(firstBookId),
              builder: (context, snap) {
                final book = snap.data;
                final cover = book?.image ?? "";
                final title = book?.title ??
                    (order.items.isNotEmpty
                        ? order.items.first.bookId
                        : "Order");

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 60,
                                height: 80,
                                child: cover.isEmpty
                                    ? Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.menu_book_outlined,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: cover,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey.shade200,
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order #${order.id}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text("Date: $dateText"),
                                  Text("Items: ${order.items.length}"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Total: ${money.format(order.total)}",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text("Payment: ${order.paymentMethod}"),
                        if (order.paymentStatus.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text("Status: ${order.paymentStatus}"),
                        ],
                        if (order.transactionId.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Txn: ${order.transactionId}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (order.addressText.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Address: ${order.addressText}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        if (order.items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Books: ${order.items.map((e) => e.bookId).take(3).join(", ")}"
                            "${order.items.length > 3 ? "..." : ""}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: order.id.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.orderTracking,
                                      arguments: order.id,
                                    );
                                  },
                            icon: const Icon(Icons.location_searching_outlined),
                            label: const Text("Track Order"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
