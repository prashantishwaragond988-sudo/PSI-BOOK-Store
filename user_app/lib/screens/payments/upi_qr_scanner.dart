import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class UpiQrScanner extends StatefulWidget {
  const UpiQrScanner({super.key});

  @override
  State<UpiQrScanner> createState() => _UpiQrScannerState();
}

class _UpiQrScannerState extends State<UpiQrScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan UPI QR')),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (c) {
          controller = c;
          c.scannedDataStream.listen((scanData) {
            if (!mounted) return;
            Navigator.of(context).pop(scanData.code);
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
