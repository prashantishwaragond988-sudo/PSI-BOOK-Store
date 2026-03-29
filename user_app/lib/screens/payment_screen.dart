import "dart:async";

import "package:flutter/material.dart";

import "../models/address_record.dart";
import "../services/address_service.dart";
import "../services/order_service.dart";
import "../utils/app_router.dart";
import "../utils/interaction_fx.dart";

class PaymentScreenArgs {
  const PaymentScreenArgs({required this.addressId});

  final String addressId;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentScreenArgs args;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _addressService = AddressService();
  final _orderService = OrderService();
  final _upiController = TextEditingController();
  final _cardController = TextEditingController();
  late final Future<AddressRecord?> _addressFuture;

  String _paymentMethod = "COD";
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _addressFuture = _loadAddress();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<AddressRecord?> _loadAddress() async {
    final requested = await _addressService.getAddressById(
      widget.args.addressId,
    );
    if (requested != null) {
      return requested;
    }
    final selectedId = await _addressService.ensureSelectedAddressId();
    if (selectedId.isEmpty) {
      return null;
    }
    return _addressService.getAddressById(selectedId);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _transactionIdForMethod(String method) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (method == "UPI") {
      return "UPI-$now";
    }
    if (method == "CARD") {
      return "CARD-$now";
    }
    return "";
  }

  Future<void> _payAndPlace(AddressRecord address) async {
    unawaited(playTapFx());
    final method = _paymentMethod;
    if (method == "UPI" && _upiController.text.trim().isEmpty) {
      _toast("Enter UPI ID");
      return;
    }
    if (method == "CARD" && _cardController.text.trim().isEmpty) {
      _toast("Enter card number");
      return;
    }

    setState(() => _placing = true);
    var dialogOpen = true;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PaymentProcessingDialog(),
      ).then((_) => dialogOpen = false),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 950));
      final orderId = await _orderService.placeOrderFromCart(
        address: address,
        paymentMethod: method,
        transactionId: _transactionIdForMethod(method),
      );
      await playSuccessFx();

      if (!mounted) {
        return;
      }

      if (dialogOpen) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      await Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.orderSuccess,
        (route) => false,
        arguments: orderId,
      );
    } catch (e) {
      if (mounted && dialogOpen) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        _toast(e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) {
        setState(() => _placing = false);
      }
    }
  }

  Widget _paymentOption({
    required String value,
    required String label,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    final selected = _paymentMethod == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withOpacity(
                theme.brightness == Brightness.dark ? 0.18 : 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          children: [
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: value,
              groupValue: _paymentMethod,
              onChanged: (v) {
                unawaited(playTapFx());
                setState(() => _paymentMethod = v ?? "COD");
              },
              title: Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected && child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildAddress(AddressRecord address) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 0 : 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Deliver To",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              "${address.fullname} (${address.mobile})",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              address.toSingleLine(),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                address.addressType.isEmpty ? "Home" : address.addressType,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment")),
      body: FutureBuilder<AddressRecord?>(
        future: _addressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final address = snapshot.data;
          if (address == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      "Address missing",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Please select and save address before payment.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        unawaited(playTapFx());
                        Navigator.pop(context);
                      },
                      child: const Text("Back To Address"),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            children: [
              _buildAddress(address),
              const SizedBox(height: 10),
              const Text(
                "Secure Payment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "Payment receiver: Admin",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              _paymentOption(value: "COD", label: "Cash On Delivery"),
              _paymentOption(
                value: "UPI",
                label: "UPI",
                child: TextField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: "UPI ID",
                    border: OutlineInputBorder(),
                    hintText: "name@upi",
                  ),
                ),
              ),
              _paymentOption(
                value: "CARD",
                label: "Card",
                child: TextField(
                  controller: _cardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Card Number",
                    border: OutlineInputBorder(),
                    hintText: "1234 5678 9012 3456",
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _placing ? null : () => _payAndPlace(address),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _placing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Pay & Place Order"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentProcessingDialog extends StatefulWidget {
  const _PaymentProcessingDialog();

  @override
  State<_PaymentProcessingDialog> createState() =>
      _PaymentProcessingDialogState();
}

class _PaymentProcessingDialogState extends State<_PaymentProcessingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: const Icon(
                    Icons.autorenew_rounded,
                    size: 42,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Processing payment...",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Please wait",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
