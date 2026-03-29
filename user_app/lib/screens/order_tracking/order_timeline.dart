import 'package:flutter/material.dart';

class OrderTimeline extends StatelessWidget {
  final List<String> steps = const [
    'Order Placed',
    'Packed',
    'Shipped',
    'Out for delivery',
    'Delivered'
  ];
  final int current;
  const OrderTimeline({super.key, this.current = 0});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: steps.length,
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final done = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: done ? Colors.green.withOpacity(.08) : Colors.white.withOpacity(.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: done ? Colors.green : Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[i],
                  style: TextStyle(fontWeight: FontWeight.w700, color: done ? Colors.green : null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
