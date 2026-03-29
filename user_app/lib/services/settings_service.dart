import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class SettingsService {
  static const _themeModeKey = "theme_mode";
  static const _localeKey = "locale_code";

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    switch (value) {
      case "light":
        return ThemeMode.light;
      case "dark":
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => "light",
      ThemeMode.dark => "dark",
      ThemeMode.system => "system",
    };
    await prefs.setString(_themeModeKey, value);
  }

  Future<Locale?> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null || code.isEmpty) return null;
    final parts = code.split("_");
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(code);
  }

  Future<void> saveLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
      return;
    }
    final code = locale.countryCode == null
        ? locale.languageCode
        : "${locale.languageCode}_${locale.countryCode}";
    await prefs.setString(_localeKey, code);
  }
}
