import 'package:flutter/material.dart';

class AddToCartButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const AddToCartButton({super.key, required this.onTap, this.label = "Add"});

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), lowerBound: 0.0, upperBound: 0.08);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: 1 + _c.value,
          child: child,
        ),
        child: Container(
          height: 34,
          width: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF5B7BFE), Color(0xFF59E2C8)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
