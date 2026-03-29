import "package:flutter/material.dart";

import "../services/settings_service.dart";

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SettingsService? service})
      : _service = service ?? SettingsService() {
    _load();
  }

  final SettingsService _service;

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> _load() async {
    _locale = await _service.loadLocale();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    await _service.saveLocale(locale);
  }
}
