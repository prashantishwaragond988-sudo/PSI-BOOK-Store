import "package:cloud_firestore/cloud_firestore.dart";

import "../models/book.dart";

class BookService {
  BookService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<Map<String, String>> streamCategoryMap() {
    return _db.collection("categories").snapshots().map((snapshot) {
      final map = <String, String>{};
      for (final doc in snapshot.docs) {
        final name = (doc.data()["name"] ?? "").toString();
        if (name.isEmpty) {
          continue;
        }
        map[doc.id] = name;
        map[name] = name;
      }
      return map;
    });
  }

  Stream<List<String>> streamCategoryNames() {
    return streamCategoryMap().map((categoryMap) {
      final names = <String>{};
      for (final entry in categoryMap.entries) {
        if (entry.key == entry.value) {
          continue;
        }
        names.add(entry.value);
      }
      final sorted = names.toList()..sort();
      return sorted;
    });
  }

  Stream<List<Book>> streamBooks() {
    return _db.collection("books").snapshots().map((snapshot) {
      final books = snapshot.docs
          .map((doc) => Book.fromMap(doc.id, doc.data()))
          .toList();
      books.sort((a, b) => a.title.compareTo(b.title));
      return books;
    });
  }

  Future<Book?> getBookById(String bookId) async {
    final doc = await _db.collection("books").doc(bookId).get();
    if (!doc.exists) {
      return null;
    }
    final data = doc.data();
    if (data == null) {
      return null;
    }
    return Book.fromMap(doc.id, data);
  }
}
