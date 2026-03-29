import "package:cloud_firestore/cloud_firestore.dart";

import "../models/product_model.dart";

class ProductService {
  ProductService._();
  static final instance = ProductService._();

  Future<List<ProductModel>> fetchProducts() async {
    final snap = await FirebaseFirestore.instance.collection("books").get();
    return snap.docs
        .map((doc) => ProductModel.fromJson({
              ...doc.data(),
              "book_id": doc.id,
            }))
        .toList();
  }
}
