import 'package:flutter/material.dart';
import '../../services/address_service.dart';
import '../../models/address_record.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AddressService();
    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      body: StreamBuilder<List<AddressRecord>>(
        stream: service.streamAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return const Center(child: Text('No addresses yet. Add one.'));
          }
          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (_, i) {
              final addr = addresses[i];
              return Card(
                child: ListTile(
                  title: Text(addr.fullname),
                  subtitle: Text("${addr.street}, ${addr.city} - ${addr.pincode}"),
                  trailing: Text(addr.addressType),
                  onTap: () => _showDetails(context, addr),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, service),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, AddressService service) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final pincode = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Address'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
              TextField(controller: state, decoration: const InputDecoration(labelText: 'State')),
              TextField(controller: pincode, decoration: const InputDecoration(labelText: 'Pincode')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              service.addAddress(
                fullname: name.text,
                mobile: phone.text,
                city: city.text,
                pincode: pincode.text,
                street: address.text,
                landmark: "",
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, AddressRecord addr) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(addr.fullname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(addr.street),
            if (addr.landmark.isNotEmpty) Text(addr.landmark),
            Text("${addr.city} - ${addr.pincode}"),
            Text("Mobile: ${addr.mobile}"),
            Text("Type: ${addr.addressType}"),
          ],
        ),
      ),
    );
  }
}
