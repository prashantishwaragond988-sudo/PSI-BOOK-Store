import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _online = true;
  StreamSubscription? _sub;

  ConnectivityProvider() {
    _sub = Connectivity().onConnectivityChanged.listen((event) {
      final resultList = event is List<ConnectivityResult> ? event : [event];
      final nowOnline = resultList.any((r) => r != ConnectivityResult.none);
      if (nowOnline != _online) {
        _online = nowOnline;
        notifyListeners();
      }
    });
  }

  bool get online => _online;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
