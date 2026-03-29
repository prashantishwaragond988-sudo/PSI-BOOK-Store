import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

class StoreInfo {
  const StoreInfo({required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status;
}

class StoreService {
  StoreService._();

  static final StoreService instance = StoreService._();

  static const String defaultStoreId = "main-store";
  static const String defaultStoreName = "Main Store";

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ValueNotifier<String> activeStoreId = ValueNotifier<String>(
    defaultStoreId,
  );
  final ValueNotifier<String> activeStoreName = ValueNotifier<String>(
    defaultStoreName,
  );

  String get currentStoreId => activeStoreId.value;
  String get currentStoreName => activeStoreName.value;

  String resolveDocStoreId(Map<String, dynamic> data) {
    final raw = (data["store_id"] ?? "").toString().trim();
    if (raw.isEmpty) {
      return defaultStoreId;
    }
    return raw;
  }

  bool isInCurrentStore(Map<String, dynamic> data) {
    return resolveDocStoreId(data) == currentStoreId;
  }

  Future<void> bootstrapForCurrentUser() async {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      activeStoreId.value = defaultStoreId;
      activeStoreName.value = defaultStoreName;
      return;
    }

    final userRef = _db.collection("users").doc(email);
    final userSnap = await userRef.get();
    final current = userSnap.data() ?? <String, dynamic>{};
    var targetStoreId = (current["active_store_id"] ?? "").toString().trim();
    if (targetStoreId.isEmpty) {
      targetStoreId = defaultStoreId;
    }

    await userRef.set({
      "email": email,
      "active_store_id": targetStoreId,
      "global_role": (current["global_role"] ?? "user").toString(),
      "store_roles": current["store_roles"] ?? <String, dynamic>{},
    }, SetOptions(merge: true));

    await _activateStoreLocal(targetStoreId);
  }

  Future<void> switchStore(String storeId) async {
    final target = storeId.trim();
    if (target.isEmpty) {
      return;
    }

    final email = _auth.currentUser?.email?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      await _db.collection("users").doc(email).set({
        "email": email,
        "active_store_id": target,
      }, SetOptions(merge: true));
    }

    await _activateStoreLocal(target);
  }

  Future<void> _activateStoreLocal(String storeId) async {
    final storeSnap = await _db.collection("stores").doc(storeId).get();
    if (storeSnap.exists) {
      final data = storeSnap.data() ?? <String, dynamic>{};
      final status = (data["status"] ?? "active").toString().toLowerCase();
      if (status != "active") {
        activeStoreId.value = defaultStoreId;
        activeStoreName.value = defaultStoreName;
        return;
      }
      final name = (data["name"] ?? storeId).toString().trim();
      activeStoreId.value = storeId;
      activeStoreName.value = name.isEmpty ? storeId : name;
      return;
    }
    activeStoreId.value = defaultStoreId;
    activeStoreName.value = defaultStoreName;
  }

  Future<List<StoreInfo>> searchStores(String query) async {
    final q = query.trim().toLowerCase();
    final snap = await _db.collection("stores").get();
    final stores = <StoreInfo>[
      const StoreInfo(
        id: defaultStoreId,
        name: defaultStoreName,
        status: "active",
      ),
    ];

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data["status"] ?? "active").toString().toLowerCase();
      if (status != "active") {
        continue;
      }
      final name = (data["name"] ?? doc.id).toString().trim();
      final normalized = name.toLowerCase();
      if (q.isNotEmpty && !normalized.contains(q)) {
        continue;
      }
      if (doc.id == defaultStoreId) {
        continue;
      }
      stores.add(
        StoreInfo(
          id: doc.id,
          name: name.isEmpty ? doc.id : name,
          status: status,
        ),
      );
    }

    stores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return stores.take(25).toList();
  }
}
