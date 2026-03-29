import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  factory AuthService() => instance;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _normalizePhone(String input) {
    return input
        .replaceAll(RegExp(r"[^\d]"), "")
        .replaceFirst(RegExp(r"^0+"), "")
        .replaceFirst(RegExp(r"^91"), ""); // basic +91 stripping
  }

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? phone,
    String? name,
  }) async {
    final normalizedPhone = phone == null ? "" : _normalizePhone(phone.trim());
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.sendEmailVerification();
    await _db.collection("users").doc(cred.user!.uid).set({
      "email": email,
      "mobile": normalizedPhone,
      "phone": normalizedPhone,
      "uid": cred.user!.uid,
      if (name != null && name.isNotEmpty) "name": name,
      "createdAt": FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Resolve a user's email from their mobile number (stored as `mobile`).
  Future<String?> emailFromPhone(String phone) async {
    final norm = _normalizePhone(phone);
    final queries = [
      _db.collection("users").where("mobile", isEqualTo: norm).limit(1).get(),
      _db.collection("users").where("phone", isEqualTo: norm).limit(1).get(),
    ];
    for (final snap in await Future.wait(queries)) {
      if (snap.docs.isEmpty) continue;
      final data = snap.docs.first.data();
      final email = (data["email"] as String?)?.trim();
      if (email != null && email.isNotEmpty) return email;
    }
    return null;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> resendVerificationEmail() => resendVerification();

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> refreshAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified == true;
  }
}
