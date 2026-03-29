import 'package:flutter/material.dart';
import 'glass_container.dart';

class GlassSearchBar extends StatelessWidget {
  const GlassSearchBar({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: 1,
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search books, authors...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
