import "package:flutter/material.dart";

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About Book Zone")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: const [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Book Zone is an online bookstore app connected to Firebase. "
                    "You can explore books, manage wishlist and cart, place orders, "
                    "and manage your profile from one place.",
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Mission: Make books easy to discover and buy for everyone.",
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
