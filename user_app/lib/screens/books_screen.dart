import "package:flutter/material.dart";

import "../services/book_service.dart";
import "../services/store_service.dart";

class BooksScreen extends StatelessWidget {
  BooksScreen({super.key});

  final _bookService = BookService();
  final _storeService = StoreService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Books")),
      body: StreamBuilder(
        stream: _bookService.streamBooks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data!;

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                title: Text(book.title.isEmpty ? "No name" : book.title),
                subtitle: Text(
                  "Price: Rs ${book.price} - ${_storeService.currentStoreName}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}
