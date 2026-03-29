import "package:flutter/material.dart";

import "../services/settings_service.dart";

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService() {
    _loadTheme();
  }

  final SettingsService _settingsService;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> _loadTheme() async {
    _themeMode = await _settingsService.loadThemeMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _settingsService.saveThemeMode(mode);
  }
}
