import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/book.dart';

class HomeProvider with ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  List<Book> topSelling = [];
  bool loading = true;
  List<String> banners = [];
  List<String> categories = const [
    'All','Fiction','Self Help','Education','Business','Comics','Kids','History','Technology'
  ];
  String selectedCategory = 'All';

  HomeProvider() {
    _stream();
  }

  void _stream() {
    _db.collection('books').snapshots().listen((snapshot) {
      topSelling = snapshot.docs.map(Book.fromDoc).toList();
      if (topSelling.isEmpty) {
        // fallback to products collection if books empty
        _db.collection('products').orderBy('sold', descending: true).limit(20).get().then((snap) {
          topSelling = snap.docs.map(Book.fromDoc).toList();
          _updateBanners();
          loading = false;
          notifyListeners();
        });
      } else {
        _updateBanners();
        loading = false;
        notifyListeners();
      }
    });
  }

  void _updateBanners() {
    banners = topSelling.take(4).map((b) => b.image).where((e) => e.isNotEmpty).toList();
    if (banners.isEmpty && topSelling.isNotEmpty) {
      banners = [topSelling.first.image];
    }
  }

  void selectCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  List<Book> get filtered {
    if (selectedCategory == 'All') return topSelling;
    return topSelling.where((b) => b.category.toLowerCase() == selectedCategory.toLowerCase()).toList();
  }
}
