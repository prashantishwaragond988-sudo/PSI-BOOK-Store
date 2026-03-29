import "package:cloud_firestore/cloud_firestore.dart";

class CategoryService {
  CategoryService._();
  static final instance = CategoryService._();

  Future<List<String>> fetchCategories() async {
    final snap = await FirebaseFirestore.instance.collection("categories").get();
    final names = snap.docs
        .map((d) => (d.data()["name"] as String?)?.trim())
        .where((e) => (e ?? "").isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    names.sort();
    return names;
  }
}
