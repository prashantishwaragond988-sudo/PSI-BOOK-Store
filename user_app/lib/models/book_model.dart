class BookModel {
  final String id;
  final String title;
  final String author;
  final String image;
  final double price;
  final double rating;
  final String category;
  final String description;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.image,
    required this.price,
    required this.rating,
    required this.category,
    required this.description,
  });

  factory BookModel.fromDoc(String id, Map<String, dynamic> data) {
    return BookModel(
      id: id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      image: data['image'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.0,
      category: data['category'] ?? 'All',
      description: data['description'] ?? '',
    );
  }
}
