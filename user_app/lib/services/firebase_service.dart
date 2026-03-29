import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();
  final _col = FirebaseFirestore.instance.collection('books');

  Future<List<BookModel>> fetchBooks() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => BookModel.fromDoc(d.id, d.data()))
        .toList();
  }

  Stream<List<BookModel>> streamBooks() {
    return _col.snapshots().map((snap) =>
        snap.docs.map((d) => BookModel.fromDoc(d.id, d.data())).toList());
  }
}
