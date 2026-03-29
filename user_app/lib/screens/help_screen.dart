import "package:flutter/material.dart";
import "help/ai_chat_screen.dart";

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _HelpBlock(
            title: "How to place an order?",
            description:
                "Add books to cart, open Checkout, save delivery address, then place your order.",
          ),
          const SizedBox(height: 10),
          const _HelpBlock(
            title: "Cart issues?",
            description:
                "Use + and - to update quantity. Swipe back to continue shopping.",
          ),
          const SizedBox(height: 10),
          const _HelpBlock(
            title: "Email verification required",
            description:
                "New accounts must verify email before login. Use Settings to resend verification.",
          ),
          const SizedBox(height: 10),
          const _HelpBlock(title: "Contact", description: "support@bookzone.com"),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            ),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text("Chat with AI assistant"),
          ),
        ],
      ),
    );
  }
}

class _HelpBlock extends StatelessWidget {
  const _HelpBlock({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(description),
          ],
        ),
      ),
    );
  }
}
