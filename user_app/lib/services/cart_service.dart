import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

import "../models/cart_line.dart";
import "book_service.dart";
import "store_service.dart";

class CartService {
  CartService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    BookService? bookService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _bookService = bookService ?? BookService(),
       _storeService = StoreService.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final BookService _bookService;
  final StoreService _storeService;

  CollectionReference<Map<String, dynamic>> _itemsRef(String userEmail) {
    final scopedDocId =
        "${_storeService.currentStoreId}__${userEmail.toLowerCase()}";
    return _db.collection("cart").doc(scopedDocId).collection("items");
  }

  String _requireUserEmail() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception("Login required");
    }
    return email;
  }

  Stream<int> streamCartCount() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value(0);
    }
    return _itemsRef(email).snapshots().map((snapshot) {
      var count = 0;
      for (final doc in snapshot.docs) {
        final rawQty = doc.data()["qty"];
        final qty = rawQty is num
            ? rawQty.toInt()
            : int.tryParse("$rawQty") ?? 1;
        count += qty;
      }
      return count;
    });
  }

  Stream<List<CartLine>> streamCartLines() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value(<CartLine>[]);
    }

    return _itemsRef(email).snapshots().asyncMap((snapshot) async {
      final lines = <CartLine>[];
      for (final doc in snapshot.docs) {
        final rawQty = doc.data()["qty"];
        final qty = rawQty is num
            ? rawQty.toInt()
            : int.tryParse("$rawQty") ?? 1;
        final book = await _bookService.getBookById(doc.id);
        if (book == null) {
          continue;
        }
        lines.add(CartLine(bookId: doc.id, qty: qty, book: book));
      }
      lines.sort(
        (a, b) => (a.book?.title ?? "").toLowerCase().compareTo(
          (b.book?.title ?? "").toLowerCase(),
        ),
      );
      return lines;
    });
  }

  Future<List<CartLine>> getCartLinesOnce() async {
    final email = _requireUserEmail();
    final snapshot = await _itemsRef(email).get();

    final lines = <CartLine>[];
    for (final doc in snapshot.docs) {
      final rawQty = doc.data()["qty"];
      final qty = rawQty is num ? rawQty.toInt() : int.tryParse("$rawQty") ?? 1;
      final book = await _bookService.getBookById(doc.id);
      if (book == null) {
        continue;
      }
      lines.add(CartLine(bookId: doc.id, qty: qty, book: book));
    }
    return lines;
  }

  Future<void> addBook(String bookId) async {
    final email = _requireUserEmail();
    await _itemsRef(email).doc(bookId).set({
      "qty": FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> decreaseBook(String bookId) async {
    final email = _requireUserEmail();
    final docRef = _itemsRef(email).doc(bookId);
    final snap = await docRef.get();
    if (!snap.exists) {
      return;
    }

    final rawQty = snap.data()?["qty"];
    final qty = rawQty is num ? rawQty.toInt() : int.tryParse("$rawQty") ?? 1;
    if (qty > 1) {
      await docRef.update({"qty": FieldValue.increment(-1)});
    } else {
      await docRef.delete();
    }
  }

  Future<void> removeBook(String bookId) async {
    final email = _requireUserEmail();
    await _itemsRef(email).doc(bookId).delete();
  }

  Future<void> clearCartByBookIds(List<String> bookIds) async {
    final email = _requireUserEmail();
    final batch = _db.batch();
    for (final id in bookIds) {
      batch.delete(_itemsRef(email).doc(id));
    }
    await batch.commit();
  }

  double totalFromLines(List<CartLine> lines) {
    return lines.fold<double>(0, (total, line) => total + line.lineTotal);
  }
}
