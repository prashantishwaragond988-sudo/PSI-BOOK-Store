import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../services/category_service.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: FutureBuilder<List<String>>(
        future: CategoryService.instance.fetchCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snapshot.data ?? [];
          if (cats.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              itemCount: cats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final name = cats[i];
                final colors = _gradientForIndex(i);
                final waveOffset = (i % 5) / 5;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final shift = (value + waveOffset) % 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment(-1 + shift * 2, -1),
                          end: Alignment(1 - shift * 2, 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {},
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconFor(name),
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fic')) return Icons.menu_book_outlined;
    if (lower.contains('self')) return Icons.psychology_outlined;
    if (lower.contains('edu') || lower.contains('study')) return Icons.school;
    if (lower.contains('bus')) return Icons.work_history_outlined;
    if (lower.contains('comic')) return Icons.auto_awesome_outlined;
    if (lower.contains('kid') || lower.contains('child')) return Icons.toys;
    if (lower.contains('tech') || lower.contains('comp'))
      return Icons.memory_outlined;
    if (lower.contains('hist')) return Icons.castle_outlined;
    if (lower.contains('sci')) return Icons.science_outlined;
    if (lower.contains('art')) return Icons.brush_outlined;
    return Icons.bookmarks_outlined;
  }

  List<Color> _gradientForIndex(int i) {
    const palettes = [
      [Color(0xFF7F7CFF), Color(0xFF61E8E1)],
      [Color(0xFFFD6F46), Color(0xFFFEB692)],
      [Color(0xFF5B7BFE), Color(0xFF59E2C8)],
      [Color(0xFF9D4EDD), Color(0xFF5A189A)],
      [Color(0xFF00B09B), Color(0xFF96C93D)],
      [Color(0xFFEF5DA8), Color(0xFFFFB6C1)],
    ];
    return palettes[i % palettes.length];
  }
}
