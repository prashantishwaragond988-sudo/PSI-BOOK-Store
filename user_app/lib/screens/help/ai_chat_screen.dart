import 'package:flutter/material.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final List<_ChatBubble> _messages = [
    const _ChatBubble(text: "Hi! I'm your bookstore assistant. Ask me anything.", isUser: false),
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatBubble(text: text, isUser: true));
      _messages.add(_ChatBubble(text: _mockReply(text), isUser: false));
    });
    _controller.clear();
  }

  String _mockReply(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains("order")) return "You can track orders from Account > Orders or using the Track button in each order card.";
    if (lower.contains("delivery")) return "Most deliveries take 3-5 business days. You'll get updates in the Orders tab.";
    if (lower.contains("refund")) return "Refunds are processed within 5-7 days after approval. Need help starting one?";
    return "Got it! I’ve noted: \"$prompt\". If you need live help, tap Help Center or email support@bookzone.com.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Chat Assistant")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _messages[i],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask a question...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _send,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final color = isUser
        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
        : Theme.of(context).colorScheme.surfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }
}
