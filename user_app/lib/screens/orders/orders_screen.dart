import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ListView.builder(
        itemCount: 3,
        itemBuilder: (_, i) => Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            title: Text('Order #${i + 1}'),
            subtitle: const Text('PLACED · Packed · Shipped · Out for delivery · Delivered'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ),
    );
  }
}
