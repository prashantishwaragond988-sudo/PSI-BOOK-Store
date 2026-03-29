import 'package:flutter/material.dart';
import '../screens/main_screen.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../screens/network/no_internet_dialog.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!online) {
        showNoInternetDialog(context);
      }
    });
    return MainScreen(initialIndex: widget.initialIndex);
  }
}
