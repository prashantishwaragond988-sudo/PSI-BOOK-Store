import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String image;
  final List<String> images;
  final double price;
  final double rating;
  final String category;
  final String description;
  final String storeId;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.image,
    required this.images,
    required this.price,
    required this.rating,
    required this.category,
    required this.description,
    this.storeId = "",
  });

  factory Book.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return Book(
      id: doc.id,
      title: m['title'] ?? '',
      author: m['author'] ?? '',
      image: m['image'] ?? '',
      images: List<String>.from(m['images'] ?? [m['image'] ?? '']),
      price: (m['price'] ?? 0).toDouble(),
      rating: (m['rating'] ?? 0).toDouble(),
      category: m['category'] ?? '',
      description: m['description'] ?? '',
      storeId: (m['store_id'] ?? m['storeId'] ?? '').toString(),
    );
  }

  factory Book.fromMap(String id, Map<String, dynamic> m) {
    return Book(
      id: id,
      title: m['title'] ?? '',
      author: m['author'] ?? '',
      image: m['image'] ?? '',
      images: List<String>.from(m['images'] ?? [m['image'] ?? '']),
      price: (m['price'] ?? 0).toDouble(),
      rating: (m['rating'] ?? 0).toDouble(),
      category: m['category'] ?? '',
      description: m['description'] ?? '',
      storeId: (m['store_id'] ?? m['storeId'] ?? '').toString(),
    );
  }
}
