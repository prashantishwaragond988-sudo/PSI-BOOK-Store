class ProductModel {
  const ProductModel({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.image,
    required this.rating,
    required this.ratingCount,
    required this.author,
  });

  final String id;
  final String title;
  final double price;
  final String description;
  final String category;
  final String image;
  final double rating;
  final int ratingCount;
  final String author;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String rawImage =
        "${json["image_url"] ?? json["image"] ?? "https://m.media-amazon.com/images/I/81sXJ3AdxML.jpg"}";
    if (rawImage.startsWith("http://")) {
      rawImage = rawImage.replaceFirst("http://", "https://");
    }
    return ProductModel(
      id: "${json["book_id"] ?? json["id"] ?? ""}",
      title: "${json["title"] ?? "Untitled"}",
      author: "${json["author"] ?? ""}",
      price: (json["price"] as num? ?? 0).toDouble(),
      description: "${json["description"] ?? ""}",
      category: "${json["category"] ?? "Books"}",
      image: rawImage,
      rating: (json["rating"] as num? ??
              json["avg_rating"] as num? ??
              4.3)
          .toDouble(),
      ratingCount: (json["rating_count"] as num? ??
              json["reviews_count"] as num? ??
              json["order_count"] as num? ??
              24)
          .toInt(),
    );
  }
}
