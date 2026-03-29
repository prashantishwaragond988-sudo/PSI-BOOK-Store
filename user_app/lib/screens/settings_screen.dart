import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../providers/theme_provider.dart";
import "../providers/settings_provider.dart";
import "../services/auth_service.dart";
import "login_screen.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService.instance;
  bool _sendingReset = false;
  bool _sendingVerify = false;
  bool _checkingVerify = false;

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _toast("No email found.");
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await _authService.sendPasswordReset(email);
      _toast("Password reset email sent.");
    } catch (error) {
      _toast("Unable to send reset email.");
    } finally {
      if (mounted) {
        setState(() => _sendingReset = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _sendingVerify = true);
    try {
      await _authService.resendVerification();
      _toast("Verification email sent.");
    } catch (error) {
      _toast("Unable to resend verification.");
    } finally {
      if (mounted) {
        setState(() => _sendingVerify = false);
      }
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _checkingVerify = true);
    try {
      final verified = await _authService.refreshAndCheckVerified();
      _toast(verified ? "Email verified." : "Email still not verified.");
      if (verified && mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _checkingVerify = false);
      }
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();

    final locales = <String, Locale?>{
      "System": null,
      "English": const Locale("en"),
      "Hindi": const Locale("hi"),
      "Kannada": const Locale("kn"),
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Account"),
                  subtitle: Text(user?.email ?? "Unknown"),
                  trailing: Text(
                    user?.emailVerified == true ? "Verified" : "Not Verified",
                    style: TextStyle(
                      color: user?.emailVerified == true
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text("Dark Mode"),
                  trailing: Switch(
                    value: theme.themeMode == ThemeMode.dark,
                    onChanged: (v) =>
                        theme.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text("Language"),
                  subtitle: Text(locales.entries
                          .firstWhere(
                            (e) => e.value == settings.locale,
                            orElse: () => locales.entries.first,
                          )
                          .key),
                  onTap: () => _showLanguageSheet(context, locales, settings),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text("Resend Verification Email"),
                  trailing: _sendingVerify
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _sendingVerify ? null : _resendVerification,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text("Check Verification Status"),
                  trailing: _checkingVerify
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _checkingVerify ? null : _checkVerification,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text("Reset Password"),
                  trailing: _sendingReset
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _sendingReset ? null : _resetPassword,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Logout"),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text("App"),
              subtitle: Text("OurStore\nVersion 1.0.0"),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context,
      Map<String, Locale?> locales, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: locales.entries.map((e) {
          final selected = e.value == settings.locale;
          return ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(e.key),
            trailing:
                selected ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              settings.setLocale(e.value);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
