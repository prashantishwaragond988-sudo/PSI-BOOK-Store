import 'package:flutter/material.dart';

Future<void> showNoInternetDialog(BuildContext context) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('No Internet'),
      content: const Text('Please turn on your internet connection'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retry')),
        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Exit')),
      ],
    ),
  );
}
