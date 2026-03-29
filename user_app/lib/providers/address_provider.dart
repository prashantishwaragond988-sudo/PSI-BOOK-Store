import 'package:flutter/foundation.dart';
import '../models/address.dart';

class AddressProvider with ChangeNotifier {
  final List<Address> _addresses = [];
  int _defaultIndex = 0;

  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get defaultAddress => _addresses.isEmpty ? null : _addresses[_defaultIndex];

  void add(Address a) {
    _addresses.add(a);
    _defaultIndex = _addresses.length - 1;
    notifyListeners();
  }

  void remove(Address a) {
    _addresses.removeWhere((x) => x.id == a.id);
    if (_defaultIndex >= _addresses.length) _defaultIndex = (_addresses.isEmpty ? 0 : _addresses.length - 1);
    notifyListeners();
  }

  void setDefault(int idx) {
    if (idx >= 0 && idx < _addresses.length) {
      _defaultIndex = idx;
      notifyListeners();
    }
  }
}
