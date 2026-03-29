import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection("users");

  Future<Map<String, dynamic>?> getUserProfile({
    required User firebaseUser,
  }) async {
    final email = firebaseUser.email?.toLowerCase();

    if (email != null && email.isNotEmpty) {
      final emailSnap = await _users.doc(email).get();
      if (emailSnap.exists) {
        final data = emailSnap.data() ?? <String, dynamic>{};
        return {...data, "doc_id": email};
      }
    }

    final uidSnap = await _users.doc(firebaseUser.uid).get();
    if (uidSnap.exists) {
      final legacy = uidSnap.data() ?? <String, dynamic>{};
      final merged = <String, dynamic>{
        "uid": firebaseUser.uid,
        "email": email ?? (legacy["email"] ?? "").toString(),
        "mobile": (legacy["mobile"] ?? "").toString(),
        "is_admin": legacy["is_admin"] ?? 0,
        "global_role": (legacy["global_role"] ?? "user").toString(),
        "active_store_id": (legacy["active_store_id"] ?? "main-store")
            .toString(),
        "store_roles": legacy["store_roles"] ?? <String, dynamic>{},
        ...legacy,
      };

      if (email != null && email.isNotEmpty) {
        await _users.doc(email).set(merged, SetOptions(merge: true));
      }

      return {...merged, "doc_id": email ?? firebaseUser.uid};
    }

    if (email == null || email.isEmpty) {
      return null;
    }

    final created = <String, dynamic>{
      "uid": firebaseUser.uid,
      "email": email,
      "mobile": "",
      "is_admin": 0,
      "global_role": "user",
      "active_store_id": "main-store",
      "store_roles": <String, dynamic>{},
      "created_at": DateTime.now().toIso8601String(),
    };
    await _users.doc(email).set(created, SetOptions(merge: true));
    return {...created, "doc_id": email};
  }

  Future<void> ensureCanonicalUserDoc({
    required User firebaseUser,
    required String mobileIfNew,
  }) async {
    final email = firebaseUser.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return;
    }

    final emailRef = _users.doc(email);
    final emailSnap = await emailRef.get();

    if (emailSnap.exists) {
      final existing = emailSnap.data() ?? <String, dynamic>{};
      final hasMobile = (existing["mobile"] ?? "").toString().isNotEmpty;
      await emailRef.set(<String, dynamic>{
        "uid": firebaseUser.uid,
        "email": email,
        "is_admin": existing["is_admin"] ?? 0,
        "global_role": existing["global_role"] ?? "user",
        "active_store_id": existing["active_store_id"] ?? "main-store",
        "store_roles": existing["store_roles"] ?? <String, dynamic>{},
        if (!hasMobile && mobileIfNew.isNotEmpty) "mobile": mobileIfNew,
      }, SetOptions(merge: true));
      return;
    }

    final legacySnap = await _users.doc(firebaseUser.uid).get();
    final legacy = legacySnap.data() ?? <String, dynamic>{};
    final merged = <String, dynamic>{
      ...legacy,
      "uid": firebaseUser.uid,
      "email": email,
      "mobile": (legacy["mobile"] ?? "").toString().isNotEmpty
          ? legacy["mobile"].toString()
          : mobileIfNew,
      "is_admin": legacy["is_admin"] ?? 0,
      "global_role": legacy["global_role"] ?? "user",
      "active_store_id": legacy["active_store_id"] ?? "main-store",
      "store_roles": legacy["store_roles"] ?? <String, dynamic>{},
      "created_at": legacy["created_at"] ?? DateTime.now().toIso8601String(),
    };
    await emailRef.set(merged, SetOptions(merge: true));
  }

  Future<String?> resolveEmailFromMobile(String mobile) async {
    final cleanMobile = normalizeMobile(mobile);
    if (cleanMobile.isEmpty) {
      return null;
    }

    final snap = await _users
        .where("mobile", isEqualTo: cleanMobile)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return null;
    }

    return (snap.docs.first.data()["email"] ?? "").toString();
  }

  String normalizeMobile(String value) {
    return value
        .replaceAll("+91", "")
        .replaceAll(" ", "")
        .replaceAll("-", "")
        .replaceAll(RegExp(r"[()]"), "")
        .replaceFirst(RegExp(r"^0+"), "");
  }
}
