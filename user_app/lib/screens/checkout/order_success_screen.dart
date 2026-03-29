import 'package:flutter/material.dart';

import '../../models/address_record.dart';
import '../order_tracking_screen.dart';
import '../orders/orders_screen.dart';
import '../root_shell.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    this.total = 0,
    this.paymentMethod = "COD",
    this.address,
  });

  final String orderId;
  final double total;
  final String paymentMethod;
  final AddressRecord? address;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final addressText = widget.address == null
        ? "No address available"
        : [
            widget.address!.fullname,
            widget.address!.street,
            if (widget.address!.landmark.isNotEmpty) widget.address!.landmark,
            widget.address!.city,
            widget.address!.pincode,
            widget.address!.mobile,
          ].where((part) => part.trim().isNotEmpty).join(", ");

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.elasticOut,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 82, color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text("Order placed!",
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 6),
              Text(
                widget.orderId.isNotEmpty
                    ? "Order ID: ${widget.orderId}"
                    : "Generating order ID...",
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow("Total paid", "₹${widget.total.toStringAsFixed(0)}"),
                      const SizedBox(height: 6),
                      _infoRow("Payment", _labelForPayment(widget.paymentMethod)),
                      const Divider(height: 22),
                      Text("Deliver to", style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(addressText),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text("Track order"),
                  onPressed: widget.orderId.isEmpty
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingScreen(orderId: widget.orderId),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                      },
                      child: const Text("View orders"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const RootShell()),
                          (route) => false,
                        );
                      },
                      child: const Text("Back to home"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _labelForPayment(String code) {
    switch (code.toUpperCase()) {
      case "CARD":
        return "Card / Netbanking";
      case "COD":
        return "Cash on Delivery";
      default:
        return "UPI / QR";
    }
  }
}
