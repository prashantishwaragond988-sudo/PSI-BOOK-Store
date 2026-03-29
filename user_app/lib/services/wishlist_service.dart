import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

import "../models/book.dart";
import "book_service.dart";
import "store_service.dart";

class WishlistService {
  WishlistService({
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
    return _db.collection("wishlist").doc(scopedDocId).collection("items");
  }

  String _requireUserEmail() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception("Login required");
    }
    return email;
  }

  Stream<Set<String>> streamWishlistIds() {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream.value(<String>{});
    }
    return _itemsRef(
      email,
    ).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Stream<int> streamWishlistCount() {
    return streamWishlistIds().map((ids) => ids.length);
  }

  Stream<List<Book>> streamWishlistBooks() {
    return streamWishlistIds().asyncMap((ids) async {
      final books = <Book>[];
      for (final id in ids) {
        final book = await _bookService.getBookById(id);
        if (book != null) {
          books.add(book);
        }
      }
      books.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return books;
    });
  }

  Future<void> toggle(String bookId) async {
    final email = _requireUserEmail();
    final docRef = _itemsRef(email).doc(bookId);
    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
      return;
    }
    await docRef.set({"added_at": DateTime.now().toIso8601String()});
  }
}
