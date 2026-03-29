import 'package:flutter/material.dart';
import 'upi_qr_scanner.dart';

class PaymentMethodsSheet extends StatelessWidget {
  const PaymentMethodsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.qr_code_scanner),
          title: const Text('UPI / QR'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpiQrScanner())),
        ),
        const ListTile(leading: Icon(Icons.credit_card), title: Text('Debit / Credit Card')),
        const ListTile(leading: Icon(Icons.money), title: Text('Cash On Delivery')),
      ],
    );
  }
}
