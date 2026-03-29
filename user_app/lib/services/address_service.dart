import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

import "../models/address_record.dart";

class AddressService {
  AddressService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String _requireUserEmail() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception("Login required");
    }
    return email;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String email) {
    return _db.collection("users").doc(email.toLowerCase());
  }

  CollectionReference<Map<String, dynamic>> _addressesRef(String email) {
    return _userDoc(email).collection("addresses");
  }

  Stream<List<AddressRecord>> streamAddresses() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value(<AddressRecord>[]);
    }
    return _addressesRef(email).snapshots().map((snapshot) {
      final rows = snapshot.docs
          .map((doc) => AddressRecord.fromMap(doc.id, doc.data()))
          .toList();
      rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rows;
    });
  }

  Future<List<AddressRecord>> getAddressesOnce() async {
    final email = _requireUserEmail();
    final snapshot = await _addressesRef(email).get();
    final rows = snapshot.docs
        .map((doc) => AddressRecord.fromMap(doc.id, doc.data()))
        .toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<String> addAddress({
    required String fullname,
    required String mobile,
    required String city,
    required String pincode,
    required String street,
    String landmark = "",
    String addressType = "Home",
  }) async {
    final email = _requireUserEmail();
    final payload = AddressRecord(
      id: "",
      fullname: fullname.trim(),
      mobile: mobile.trim(),
      city: city.trim(),
      pincode: pincode.trim(),
      street: street.trim(),
      landmark: landmark.trim(),
      addressType: addressType.trim().isEmpty ? "Home" : addressType.trim(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ).toMap(email);

    final ref = await _addressesRef(email).add(payload);
    await _db
        .collection("address")
        .doc(ref.id)
        .set(payload, SetOptions(merge: true));
    return ref.id;
  }

  Future<AddressRecord?> getAddressById(String addressId) async {
    final email = _requireUserEmail();
    final id = addressId.trim();
    if (id.isEmpty) {
      return null;
    }

    final own = await _addressesRef(email).doc(id).get();
    if (own.exists) {
      final data = own.data() ?? <String, dynamic>{};
      return AddressRecord.fromMap(own.id, data);
    }

    final legacy = await _db.collection("address").doc(id).get();
    if (!legacy.exists) {
      return null;
    }
    final data = legacy.data() ?? <String, dynamic>{};
    final owner = (data["user"] ?? "").toString().trim().toLowerCase();
    if (owner.isNotEmpty && owner != email) {
      return null;
    }

    await _addressesRef(
      email,
    ).doc(legacy.id).set(data, SetOptions(merge: true));
    return AddressRecord.fromMap(legacy.id, data);
  }

  Stream<String> streamSelectedAddressId() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value("");
    }
    return _userDoc(email).snapshots().map((snapshot) {
      final data = snapshot.data() ?? <String, dynamic>{};
      return (data["selected_address_id"] ?? "").toString().trim();
    });
  }

  Future<String> getSelectedAddressId() async {
    final email = _requireUserEmail();
    final snap = await _userDoc(email).get();
    final data = snap.data() ?? <String, dynamic>{};
    return (data["selected_address_id"] ?? "").toString().trim();
  }

  Future<void> selectAddress(String addressId) async {
    final email = _requireUserEmail();
    final id = addressId.trim();
    if (id.isEmpty) {
      return;
    }

    final address = await getAddressById(id);
    if (address == null) {
      throw Exception("Address not found");
    }

    await _userDoc(email).set({
      "email": email,
      "selected_address_id": id,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<String> ensureSelectedAddressId() async {
    final email = _requireUserEmail();
    var selected = await getSelectedAddressId();
    if (selected.isNotEmpty) {
      final selectedAddress = await getAddressById(selected);
      if (selectedAddress != null) {
        return selected;
      }
    }

    final rows = await getAddressesOnce();
    if (rows.isEmpty) {
      return "";
    }

    selected = rows.first.id;
    await _userDoc(email).set({
      "email": email,
      "selected_address_id": selected,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
    return selected;
  }
}
