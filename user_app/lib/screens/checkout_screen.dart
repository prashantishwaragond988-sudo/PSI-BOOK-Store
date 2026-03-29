import "dart:async";

import "package:flutter/material.dart";

import "../models/address_record.dart";
import "../services/address_service.dart";
import "../services/cart_service.dart";
import "../utils/app_router.dart";
import "../utils/interaction_fx.dart";

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cartService = CartService();
  final _addressService = AddressService();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();

  bool _savingAddress = false;
  bool _continuing = false;
  bool _autoSelecting = false;
  String _selectedAddressId = "";
  String _addressType = "Home";
  late final Future<bool> _hasCartItemsFuture;

  @override
  void initState() {
    super.initState();
    _hasCartItemsFuture = _hasCartItems();
    _syncSelectedAddress();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _hasCartItems() async {
    try {
      final lines = await _cartService.getCartLinesOnce();
      return lines.any((line) => line.qty > 0 && line.book != null);
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncSelectedAddress() async {
    try {
      final id = await _addressService.ensureSelectedAddressId();
      if (!mounted) {
        return;
      }
      setState(() => _selectedAddressId = id);
    } catch (_) {}
  }

  Future<void> _selectAddress(String addressId) async {
    unawaited(playTapFx());
    final id = addressId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      await _addressService.selectAddress(id);
      if (!mounted) {
        return;
      }
      setState(() => _selectedAddressId = id);
      _toast("Address selected");
    } catch (_) {
      _toast("Unable to select address.");
    }
  }

  void _autoSelectFirstAddress(List<AddressRecord> addresses) {
    if (_selectedAddressId.isNotEmpty || addresses.isEmpty || _autoSelecting) {
      return;
    }
    _autoSelecting = true;
    final firstId = addresses.first.id;
    _addressService
        .selectAddress(firstId)
        .then((_) {
          if (mounted) {
            setState(() => _selectedAddressId = firstId);
          }
        })
        .whenComplete(() => _autoSelecting = false);
  }

  Future<void> _saveAddress() async {
    unawaited(playTapFx());
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final id = await _addressService.addAddress(
        fullname: _nameController.text,
        mobile: _mobileController.text,
        city: _cityController.text,
        pincode: _pinController.text,
        street: _streetController.text,
        landmark: _landmarkController.text,
        addressType: _addressType,
      );
      await _addressService.selectAddress(id);
      if (!mounted) {
        return;
      }
      setState(() => _selectedAddressId = id);
      _nameController.clear();
      _mobileController.clear();
      _cityController.clear();
      _pinController.clear();
      _streetController.clear();
      _landmarkController.clear();
      _addressType = "Home";
      _toast("Address saved");
    } catch (_) {
      _toast("Unable to save address.");
    } finally {
      if (mounted) {
        setState(() => _savingAddress = false);
      }
    }
  }

  Future<void> _continueToPayment() async {
    unawaited(playTapFx());
    final selectedId = _selectedAddressId.trim();
    if (selectedId.isEmpty) {
      _toast("Select an address first.");
      return;
    }

    setState(() => _continuing = true);
    try {
      final address = await _addressService.getAddressById(selectedId);
      if (address == null) {
        _toast("Address not found. Please select again.");
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.pushNamed(
        context,
        AppRouter.payment,
        arguments: address.id,
      );
      await _syncSelectedAddress();
    } catch (_) {
      _toast("Unable to continue.");
    } finally {
      if (mounted) {
        setState(() => _continuing = false);
      }
    }
  }

  void _goToCart() {
    unawaited(playTapFx());
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.main,
      (route) => false,
      arguments: 2,
    );
  }

  Widget _addressCard(AddressRecord address) {
    final selected = address.id == _selectedAddressId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withOpacity(
                isDark ? 0.18 : 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.05),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${address.fullname} (${address.mobile})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    address.addressType.isEmpty ? "Home" : address.addressType,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              address.toSingleLine(),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: selected ? null : () => _selectAddress(address.id),
                child: Text(selected ? "Selected" : "Deliver Here"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.black45,
            ),
            const SizedBox(height: 14),
            const Text(
              "Your cart is empty",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              "Add at least one book before moving to checkout.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _goToCart, child: const Text("Go To Cart")),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressFormCard() {
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add New Address",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _addressType,
                items: const [
                  DropdownMenuItem(value: "Home", child: Text("Home")),
                  DropdownMenuItem(value: "Work", child: Text("Work")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) =>
                    setState(() => _addressType = value ?? "Home"),
                decoration: const InputDecoration(
                  labelText: "Address Type",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Mobile",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Enter mobile"
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Pincode",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Enter pincode"
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: "City",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Enter city" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _streetController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Street Address",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Enter street address"
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: "Landmark (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _savingAddress ? null : _saveAddress,
                  child: _savingAddress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save Address"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Address")),
      body: FutureBuilder<bool>(
        future: _hasCartItemsFuture,
        builder: (context, cartSnapshot) {
          if (cartSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final hasItems = cartSnapshot.data ?? false;
          if (!hasItems) {
            return _emptyCartView();
          }

          return StreamBuilder<List<AddressRecord>>(
            stream: _addressService.streamAddresses(),
            builder: (context, snapshot) {
              final addresses = snapshot.data ?? const <AddressRecord>[];
              _autoSelectFirstAddress(addresses);

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                children: [
                  const Text(
                    "Saved Addresses",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (addresses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          "No saved addresses yet. Add one to continue.",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ...addresses.map(_addressCard),
                  const SizedBox(height: 6),
                  _buildAddressFormCard(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _continuing ? null : _continueToPayment,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _continuing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Continue To Payment"),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
