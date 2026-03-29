import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/address.dart';
import '../../models/address_record.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/gradient_button.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 0;
  String _paymentMethod = "UPI";
  bool _placing = false;
  Address? _selectedAddress;

  @override
  void initState() {
    super.initState();
    final prov = context.read<AddressProvider>();
    _selectedAddress = prov.defaultAddress;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final addrProv = context.watch<AddressProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _step,
          onStepTapped: (i) => setState(() => _step = i),
          controlsBuilder: (context, details) => _controls(cart),
          onStepContinue: () => _onContinue(cart),
          onStepCancel: _onBack,
          steps: [
            Step(
              title: const Text('Address'),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: _addressStep(addrProv),
            ),
            Step(
              title: const Text('Payment'),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: _paymentStep(),
            ),
            Step(
              title: const Text('Review'),
              isActive: _step >= 2,
              state: _step == 2 ? StepState.indexed : StepState.complete,
              content: _reviewStep(cart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(CartProvider cart) {
    final primaryLabel = _step == 2
        ? (_paymentMethod == "COD" ? "Place Order" : "Pay & Place Order")
        : "Next";
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _placing ? null : () => _onContinue(cart),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _placing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
          ),
          if (_step > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: _placing ? null : _onBack,
              child: const Text("Back"),
            ),
          ]
        ],
      ),
    );
  }

  Widget _addressStep(AddressProvider prov) {
    final addresses = prov.addresses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
            child: const Text("No saved addresses. Add one to continue."),
          ),
        ...addresses.map((addr) {
          final isSelected = _selectedAddress?.id == addr.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedAddress = addr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                    : Theme.of(context).colorScheme.surfaceVariant.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.4
                              : 1,
                        ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(addr.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                            "${addr.address}, ${addr.city} · ${addr.state} · ${addr.pincode}"),
                        Text("Phone: ${addr.phone}"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _placing ? null : () => _openAddAddressSheet(prov),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text("Add new address"),
        ),
      ],
    );
  }

  Widget _paymentStep() {
    final options = <String, IconData>{
      "UPI": Icons.qr_code_scanner,
      "CARD": Icons.credit_card,
      "COD": Icons.money,
    };
    return Column(
      children: options.entries
          .map(
            (entry) => RadioListTile<String>(
              value: entry.key,
              groupValue: _paymentMethod,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => _paymentMethod = v ?? "UPI"),
              title: Text(_labelForPayment(entry.key)),
              secondary: Icon(entry.value),
            ),
          )
          .toList(),
    );
  }

  Widget _reviewStep(CartProvider cart) {
    final address = _selectedAddress;
    final items = cart.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address != null)
          _summaryTile(
            title: "Deliver to",
            subtitle:
                "${address.name}, ${address.address}, ${address.city}, ${address.state} - ${address.pincode}",
            trailing: "Change",
            onTap: () => setState(() => _step = 0),
          )
        else
          _summaryTile(
            title: "No address selected",
            subtitle: "Add an address to continue",
            trailing: "Add",
            onTap: () => setState(() => _step = 0),
          ),
        const SizedBox(height: 10),
        _summaryTile(
          title: "Payment",
          subtitle: _labelForPayment(_paymentMethod),
          trailing: "Change",
          onTap: () => setState(() => _step = 1),
        ),
        const Divider(),
        Text("Order summary",
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text("Your cart is empty.")
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(item.product.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text("×${item.quantity}"),
                  const SizedBox(width: 8),
                  Text("₹${(item.product.price * item.quantity).toStringAsFixed(0)}"),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text("₹${cart.totalPrice.toStringAsFixed(0)}",
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 16),
        GradientButton(
          text: _paymentMethod == "COD"
              ? "Place Order"
              : "Pay & Place Order",
          onTap: () {
            if (_placing) return;
            _placeOrder(cart);
          },
        ),
      ],
    );
  }

  Widget _summaryTile({
    required String title,
    required String subtitle,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing != null ? Text(trailing) : null,
      onTap: onTap,
    );
  }

  void _onContinue(CartProvider cart) {
    if (_step == 0) {
      if (_selectedAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select or add an address to continue")),
        );
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() => _step = 2);
    } else {
      _placeOrder(cart);
    }
  }

  void _onBack() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your cart is empty")),
      );
      return;
    }
    final addr = _selectedAddress;
    if (addr == null) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select an address to place order")),
      );
      return;
    }
    setState(() => _placing = true);
    final addressRecord = AddressRecord(
      id: addr.id,
      fullname: addr.name,
      mobile: addr.phone,
      city: addr.city,
      pincode: addr.pincode,
      street: addr.address,
      landmark: "",
      addressType: "Home",
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      final total = cart.totalPrice;
      final orderId = await OrderService().placeOrderFromCart(
        address: addressRecord,
        paymentMethod: _paymentMethod,
      );
      await cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: orderId,
            total: total,
            paymentMethod: _paymentMethod,
            address: addressRecord,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not place order: $e")),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _openAddAddressSheet(AddressProvider prov) {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final stateCtrl = TextEditingController();
    final pincode = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Text("Add Address",
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "Full name"),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : "Required",
                ),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: "Mobile"),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v != null && v.trim().length >= 6 ? null : "Required",
                ),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: "Street / House"),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : "Required",
                ),
                TextFormField(
                  controller: city,
                  decoration: const InputDecoration(labelText: "City"),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : "Required",
                ),
                TextFormField(
                  controller: stateCtrl,
                  decoration: const InputDecoration(labelText: "State"),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : "Required",
                ),
                TextFormField(
                  controller: pincode,
                  decoration: const InputDecoration(labelText: "Pincode"),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v != null && v.trim().length >= 4 ? null : "Required",
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final addr = Address(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                        address: address.text.trim(),
                        city: city.text.trim(),
                        state: stateCtrl.text.trim(),
                        pincode: pincode.text.trim(),
                      );
                      prov.add(addr);
                      setState(() => _selectedAddress = addr);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Save & Select"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelForPayment(String code) {
    switch (code) {
      case "CARD":
        return "Card / Netbanking";
      case "COD":
        return "Cash on Delivery";
      default:
        return "UPI / QR";
    }
  }
}
