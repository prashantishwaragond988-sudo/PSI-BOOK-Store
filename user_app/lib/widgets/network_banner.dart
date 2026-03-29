import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: online ? 0 : 44,
      color: Colors.red.shade600,
      child: const Center(
        child: Text('OFFLINE MODE · Please check connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
