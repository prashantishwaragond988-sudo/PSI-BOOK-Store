import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../services/auth_service.dart";
import "root_shell.dart";
import "../animations/popup_success.dart";
import "../widgets/glass.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isLoading = false;
  String email = "";
  String password = "";
  String name = "";
  String phone = "";
  bool termsAccepted = true;
  String error = "";

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  void _toggle() => setState(() {
        isLogin = !isLogin;
        error = "";
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (!isLogin && !termsAccepted) {
      setState(() {
        error = "Please accept terms to continue.";
      });
      return;
    }
    setState(() {
      isLoading = true;
      error = "";
    });
    try {
      // If user entered a phone number, try to resolve to email.
      if (!email.contains("@")) {
        final resolved = await AuthService.instance.emailFromPhone(email);
        if (resolved == null) {
          setState(() => error = "Phone not registered. Use email or sign up.");
          return;
        }
        email = resolved;
      }

      if (isLogin) {
        final cred =
            await AuthService.instance.signIn(email: email, password: password);
        if (!cred.user!.emailVerified) {
          await cred.user!.sendEmailVerification();
          await AuthService.instance.signOut();
          setState(() => error = "Verify your email. We sent a new link.");
          return;
        }
      } else {
        await AuthService.instance
            .signUp(email: email, password: password, phone: phone, name: name);
        setState(() =>
            error = "Verification email sent. Please verify, then login.");
        return;
      }
      if (mounted) {
        await showSuccess(
          context,
          "Welcome back! Login successful.",
          title: "Logged in",
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootShell()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? "Authentication failed");
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0f4ed8), Color(0xFF0ed3a3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Glass(
                        radius: 18,
                        opacity: 0.2,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.menu_book_rounded,
                              size: 30, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("PSI Book Store",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22)),
                          Text("Books only · Flipkart-style",
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isLogin ? "Welcome back" : "Create your account",
                      key: ValueKey(isLogin),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? "Login with email/password or mobile."
                        : "Register to sync cart and wishlist.",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: Glass(
                      radius: 20,
                      opacity: 0.18,
                      borderOpacity: 0.25,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Form(
                          key: _formKey,
                          child: Column(children: _formFields()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _formFields() {
    return [
      if (!isLogin) ...[
        TextFormField(
          decoration: const InputDecoration(
            labelText: "Full name",
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onSaved: (v) => name = v!.trim(),
          validator: (v) =>
              v != null && v.trim().length >= 2 ? null : "Enter your name",
        ),
        const SizedBox(height: 12),
      ],
      TextFormField(
        decoration: const InputDecoration(
          labelText: "Email or mobile",
          prefixIcon: Icon(Icons.alternate_email),
        ),
        keyboardType: TextInputType.emailAddress,
        onSaved: (v) => email = v!.trim(),
        validator: (v) => v != null && v.isNotEmpty ? null : "Required",
      ),
      const SizedBox(height: 12),
      TextFormField(
        decoration: const InputDecoration(
          labelText: "Password",
          prefixIcon: Icon(Icons.lock_outline),
        ),
        obscureText: true,
        controller: _passwordController,
        onChanged: (v) => password = v,
        onSaved: (v) => password = v!.trim(),
        validator: (v) => v != null && v.length >= 6 ? null : "Min 6 chars",
      ),
      if (!isLogin) ...[
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: "Confirm password",
            prefixIcon: Icon(Icons.lock_person_outlined),
          ),
          obscureText: true,
          controller: _confirmController,
          validator: (v) {
            final value = v ?? "";
            if (value.isEmpty) {
              return "Confirm password";
            }
            if (value != _passwordController.text) {
              return "Passwords do not match";
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: "Mobile (optional)",
            prefixIcon: Icon(Icons.phone_iphone),
          ),
          keyboardType: TextInputType.phone,
          onSaved: (v) => phone = v!.trim(),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: termsAccepted,
          onChanged: (v) => setState(() => termsAccepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            "I agree to the Terms and Privacy Policy.",
            style: TextStyle(fontSize: 13),
          ),
          dense: true,
        ),
      ],
      const SizedBox(height: 16),
      if (error.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            error,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFF0f4ed8),
          ),
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isLogin ? "Login" : "Sign Up"),
        ),
      ),
      TextButton(
        onPressed: isLoading ? null : _toggle,
        child: Text(
          isLogin ? "New here? Create account" : "Already have an account? Login",
        ),
      ),
      if (!isLogin)
        const Text(
          "A verification link will be sent to your email.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
    ];
  }
}

